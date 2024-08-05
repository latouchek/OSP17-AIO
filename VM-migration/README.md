
# Migrating VMs from VMware to OpenStack using virt-v2v

This guide provides a step-by-step process for migrating a virtual machine (VM) from VMware to OpenStack, using the `virt-v2v` tool to convert VM disks into a bootable qcow2 format on KVM.

## Example 1: Migrating a Windows Server 2022 VM

#### Step 1: Export the VM in OVF or OVA format
First, export the VM from VMware in OVF format.

To export VMs from VMware for migration or backup, you can use tools like `govc` or Ansible. Both options offer robust ways to handle VM exports, depending on whether you prefer command-line operations or automation playbooks.

#### Method 1: Exporting with `govc`

`govc` is a CLI tool that provides a streamlined way to interact with vSphere environments. Here's how you can export a VM using `govc`:

1. **Set up `govc` environment:**
   ```bash
   export GOVC_URL='vcenter fqdn or ip'
   export GOVC_USERNAME='your-username'
   export GOVC_PASSWORD='your-password'
   export GOVC_INSECURE=true  # Set to false if using SSL/TLS
   ```

2. **Locate your VM:**
   ```bash
   govc ls /dc/vm
   ```

3. **Export the VM:**

     ```bash
     govc export.ovf -vm 'MyVM' /path/to/export
     ```

   Replace `'MyVM'` with your VM's name and specify the destination path.

#### Method 2: Exporting with Ansible
In progress

#### Step 2: Convert the VM using virt-v2v
To convert the VM disks to a bootable qcow2 format, use the following command:

```bash
virt-v2v -i ova Windows-ovf -o local -of qcow2 -os Windows-kvm
```

- **`-i ova`**: Specifies the input format as an OVA package, containing the VM's OVF descriptor and disk images.
- **`Windows-ovf`**: Path to the source OVA file for conversion.
- **`-o local`**: Indicates the output will be saved to the local filesystem.
- **`-of qcow2`**: Sets the output disk format to qcow2, which supports features like dynamic allocation and snapshots, making it suitable for KVM.
- **`-os Windows-kvm`**: Directory where the converted files, including the qcow2 image, will be stored.



Example output:
```
[   0.0] Setting up the source: -i ova Windows-ovf
virt-v2v: warning: making OVA directory public readable to work around 
libvirt bug https://bugzilla.redhat.com/1045069
[   6.5] Opening the source
[  10.9] Inspecting the source
[  14.0] Checking for sufficient free disk space in the guest
[  14.0] Converting Windows Server 2022 Datacenter to run on KVM
virt-v2v: warning: Balloon Server (blnsvr.exe) not found on tools 
ISO/directory. You may want to install this component manually after 
conversion.
virt-v2v: warning: there are no virtio drivers available for this version 
of Windows (10.0 x86_64 Server win2k22).  virt-v2v looks for drivers in 
/usr/share/virtio-win/virtio-win.iso

The guest will be configured to use slower emulated devices.
virt-v2v: This guest does not have virtio drivers installed.
[  28.8] Mapping filesystem data to avoid copying unused and blank areas
[  29.6] Closing the overlay
[  29.9] Assigning disks to buses
[  29.9] Checking if the guest needs BIOS or UEFI to boot
virt-v2v: This guest requires UEFI on the target to boot.
[  29.9] Setting up the destination: -o disk -os .
[  31.0] Copying disk 1/1
█ 100% [****************************************]
[ 107.5] Creating output metadata
[ 107.5] Finishing off
```

#### Step 3: Fixing the VirtIO Drivers Issue

VirtIO drivers are essential for making your VM run smoothly. They replace slow, emulated hardware with fast, paravirtualized devices. Without them, you're stuck with sluggish disk and network speeds.

To get the latest VirtIO drivers, do this:

1. **Download the Latest VirtIO Driver ISO:**

   ```bash
   wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.248-1/virtio-win.iso -O /usr/share/virtio-win/virtio-win-latest.iso
   ```

   Grab the latest VirtIO drivers to make sure your VM has what it needs.

2. **Update the ISO Link:**

   ```bash
   ln -sf /usr/share/virtio-win/virtio-win-latest.iso /usr/share/virtio-win/virtio-win.iso
   ```

   Keep it simple: point `virtio-win.iso` to the latest version.


#### Step 4: Rerun the Conversion with VirtIO Drivers
```bash
virt-v2v -i ova Windows-ovf -o local -of qcow2 -os Windows-kvm
```

Example output:
```
[   0.0] Setting up the source: -i ova Windows-ovf
virt-v2v: warning: making OVA directory public readable to work around 
libvirt bug https://bugzilla.redhat.com/1045069
[   6.4] Opening the source
[  10.8] Inspecting the source
[  14.0] Checking for sufficient free disk space in the guest
[  14.0] Converting Windows Server 2022 Datacenter to run on KVM
virt-v2v: This guest has virtio drivers installed.
[  35.8] Mapping filesystem data to avoid copying unused and blank areas
[  36.7] Closing the overlay
[  36.9] Assigning disks to buses
[  36.9] Checking if the guest needs BIOS or UEFI to boot
virt-v2v: This guest requires UEFI on the target to boot.
[  36.9] Setting up the destination: -o disk -os Windows-kvm
[  38.0] Copying disk 1/1
█ 100% [****************************************]
[ 112.4] Creating output metadata
[ 112.4] Finishing off
```

#### Step 5: Verify the Conversion
To verify the converted files, navigate to the output directory and inspect the qcow2 image:

```bash
cd Windows-kvm/
qemu-img info 'Windows Server 2022-sda'
```

Output:
```
image: Windows Server 2022-sda
file format: qcow2
virtual size: 60 GiB (64424509440 bytes)
disk size: 9.75 GiB
cluster_size: 65536
Format specific information:
    compat: 1.1
    compression type: zlib
    lazy refcounts: false
    refcount bits: 16
    corrupt: false
    extended l2: false
Child node '/file':
    filename: Windows Server 2022-sda
    protocol type: file
    file length: 9.75 GiB (10464591872 bytes)
    disk size: 9.75 GiB
```

#### Step 6: Create a UEFI-Compatible Glance Image

After converting the VM to a qcow2 format, you need to ensure it boots with UEFI, as noted:

```
virt-v2v: This guest requires UEFI on the target to boot.
```

To handle this, create the Glance image with UEFI support:

```bash
openstack image create "Windows Server 2022" \
  --file "Windows Server 2022-sda" \
  --disk-format qcow2 \
  --container-format bare \
  --property hw_firmware_type=uefi \
  --public
```

#### Breakdown:

- **`--file "Windows Server 2022-sda"`**: Path to the qcow2 file.
- **`--disk-format qcow2`**: Specifies the image format.
- **`--container-format bare`**: No additional container, just the raw image.
- **`--property hw_firmware_type=uefi`**: Tells OpenStack this image needs UEFI to boot.
- **`--public`**: Makes the image accessible to everyone.


## Example 2: Migrating a Linux VM with virt-v2v

Now, let's walk through the process of migrating a Fedora Linux VM using `virt-v2v`. The steps are similar to those for a Windows VM, but with some Linux-specific considerations.

#### Step 1: Prepare the Destination Directory

First, create a directory to store the converted VM's files:

```bash
mkdir Fedora-kvm
```

This directory will hold the qcow2 image and other output files.

#### Step 2: Convert the VM using virt-v2v

Next, use the `virt-v2v` tool to convert the OVA package to a format compatible with KVM. The command is as follows:

```bash
virt-v2v -i ova Fedora-ovf -o local -os Fedora-kvm
```


### Post-Conversion Steps

1. **Verify the Image**  
   After conversion, verify the qcow2 image and ensure it's correctly set up.
   ```bash
   qemu-img info 'Fedora 64-bit-sda'
   ```
    ```bash
    image: Fedora 64-bit-sda
    file format: raw
    virtual size: 10 GiB (10737418240 bytes)
    disk size: 1.81 GiB
    Child node '/file':
        filename: Fedora 64-bit-sda
        protocol type: file
        file length: 10 GiB (10737418240 bytes)
        disk size: 1.81 GiB
    ```



2. **Upload to Glance**  
   To use the converted VM in OpenStack, upload it to Glance in the raw format:

   ```bash
   openstack image create "Fedora Linux 40" \
     --file "Fedora 64-bit-sda" \
     --disk-format raw \
     --container-format bare \
     --public
   ```

   If you prefer to use the qcow2 format, you can convert the image before uploading. First, convert the raw image to qcow2:

   ```bash
   qemu-img convert -f raw -O qcow2 "Fedora 64-bit-sda" "Fedora_64-bit.qcow2"
   ```

   This command converts the raw image `Fedora 64-bit-sda` to a qcow2 image named `Fedora_64-bit.qcow2`.

   **Upload the Converted Image to Glance:**

   ```bash
   openstack image create "Fedora 64-bit" \
     --file "Fedora_64_bit.qcow2" \
     --disk-format qcow2 \
     --container-format bare \
     --public
   ```

   This command registers the qcow2 image with Glance, making it available for launching instances in OpenStack. Choose the format that best suits your use case; raw for performance and simplicity, or qcow2 for advanced features like snapshots and compression.



3. **Manual Adjustments**  
   If there were any warnings about device mappings, GRUB configuration issues, or other system settings, it's essential to address these before attempting to boot the VM. 

   **Using `virt-customize`:**  
   `virt-customize` is a versatile tool that allows you to modify virtual machine disk images. You can use it to fix GRUB configurations, install drivers, and make other necessary changes to the VM image. This ensures the VM is properly configured before booting.

   **Example: Adjusting GRUB Configuration**

   ```bash
   virt-customize -a "Fedora_64-bit.qcow2" --run-command 'grub2-mkconfig -o /boot/grub2/grub.cfg'
   ```

   This command updates the GRUB configuration file in the qcow2 image. You can also use `virt-customize` to install missing packages, set up network configurations, or perform other tasks that might be required.

   **Additional Adjustments:**
   - **Network Configuration**: Ensure network interfaces are correctly mapped and configured.
   - **Driver Installation**: Install any necessary VirtIO drivers if they were not included during the conversion process.
   - **File System Checks**: Run file system checks and repairs if there were any indications of file system issues.

   Using `virt-customize` or similar tools, you can make these adjustments safely without needing to boot the VM, thus preventing potential boot failures and ensuring a smoother transition into the OpenStack environment. This approach also allows for automation and scripting, making it easier to apply consistent changes across multiple VM images.
