
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



## Example 3: Using the Conversion Appliance

While the previous method is effective, it is not optimal for large-scale or production environments due to its manual and time-consuming steps of downloading the VM, converting it locally, and uploading it to Glance.

For a more efficient and production-ready approach, consider using the **Conversion Appliance**.

The Conversion Appliance is an OpenStack instance configured to run **virt-v2v** with all necessary dependencies. It connects directly to the VMware vCenter Server and streams each disk of the source VM into corresponding Cinder volumes within OpenStack. This process eliminates the need for manual handling of VM disk images and significantly reduces migration time.

At the end of the conversion, the Conversion Appliance will have as many attached Cinder volumes as the source VM has disks.

**Post-Conversion Steps:**

1. **Detach the Volumes:** Detach the Cinder volumes from the Conversion Appliance.
2. **Create a New Instance:** Use the detached volumes to create a new OpenStack instance, ensuring the boot volume corresponds to the source VM's primary disk.

**Prerequisites:**

- **OpenStack Authentication:** Since **virt-v2v** must interact with the OpenStack APIs to create Cinder volumes, the Conversion Appliance requires authentication credentials. Ensure that the `overcloudrc` file or `clouds.yaml`, along with the OpenStack client (`python-openstackclient`), is accessible within the appliance.

- **Network Connectivity:** The appliance must have network connectivity to the VMware vCenter Server to access the source VM.

  **Important:** Verify that the network path between the Conversion Appliance and the vCenter Server is free of bottlenecks. Because **virt-v2v** streams a considerable amount of data during the migration process, any network limitations can significantly impact performance. A high-bandwidth, low-latency connection is essential to ensure a smooth and efficient migration.

- **VDDK Installation:** Install the VMware Virtual Disk Development Kit (VDDK) on the Conversion Appliance. The VDDK provides the necessary libraries for **virt-v2v** to access VMware virtual disk files (VMDKs) directly.

**Deployment Assistance:**

A Terraform script is provided in this repository to help you quickly deploy and configure the Conversion Appliance with all required components and credentials.

In the example below, we will walk through the entire migration process using the Conversion Appliance.

### Example Command Breakdown

Let's examine an example **virt-v2v** command to understand how each option contributes to the migration:

```bash
virt-v2v -ic 'vpx://username%40domain@vcenter.example.com/Datacenter/host/Cluster/ESXiHost?no_verify=1' \
    -it vddk -io vddk-libdir=/path/to/vmware-vix-disklib-distrib/ \
    -io vddk-thumbprint=YOUR_VCENTER_THUMBPRINT "SourceVM" \
    -ip vmware -o openstack \
    -oo server-id=conversion-appliance -oo guest-id=SourceVM-vddk
```

### Option Explanations

1. **`-ic 'vpx://username%40domain@vcenter.example.com/Datacenter/host/Cluster/ESXiHost?no_verify=1'`**  
   Specifies the input connection URL to the VMware vCenter server. This URL includes:
   - **`username%40domain`**: The vCenter username (e.g., `admin%40vsphere.local` where `@` is encoded as `%40`).
   - **`vcenter.example.com`**: The hostname or IP address of the vCenter server.
   - **`Datacenter/host/Cluster/ESXiHost`**: The path to the ESXi host where the source VM resides.
   - **`?no_verify=1`**: Disables SSL certificate verification, useful when using self-signed certificates.

2. **`-it vddk`**  
   Sets the input transport method to VDDK (VMware Virtual Disk Development Kit), enabling direct access to VMDK files.

3. **`-io vddk-libdir=/path/to/vmware-vix-disklib-distrib/`**  
   Specifies the directory where the VMware VDDK libraries are located.

   **Obtaining the VDDK**: Download the VDDK from VMware’s website (usually available in the support section under product downloads). Ensure that you download a version compatible with your VMware infrastructure, and extract the VDDK files into a directory accessible to **virt-v2v** on the Conversion Appliance.

4. **`-io vddk-thumbprint=YOUR_VCENTER_THUMBPRINT`**  
   Provides the SSL thumbprint of the vCenter server for secure communication.

   **Tip**: You can obtain the thumbprint using the following command:

   ```bash
   thumbprint=$(openssl s_client -connect your-vcenter-server:443 -showcerts </dev/null 2>/dev/null \
   | openssl x509 -fingerprint -noout | awk -F'=' '{print $2}')
   ```

5. **`"SourceVM"`**  
   The name of the source VM in VMware that you want to convert.

6. **`-ip vmware`**  
   Identifies VMware as the input provider.

7. **`-o openstack`**  
   Sets the output to OpenStack, signaling **virt-v2v** to format the VM appropriately.

8. **`-oo server-id=conversion-appliance`**  
   Specifies the ID or name of the Conversion Appliance instance in OpenStack.

9. **`-oo guest-id=SourceVM-vddk`**  
   Sets the name prefix for the Cinder volumes attached to the Conversion Appliance, helping to identify the volumes associated with the source VM.

## Interpreting the Command Output

Running the command generates output similar to the following:

```plaintext
[   1.0] Setting up the source: -i libvirt -ic vpx://username%40domain@vcenter.example.com/... -it vddk SourceVM
[   8.3] Opening the source
[  26.1] Inspecting the source
[  44.8] Checking for sufficient free disk space in the guest
[  44.8] Converting [Operating System] to run on KVM
virt-v2v: The QEMU Guest Agent will be installed for this guest at first boot.

** (process:12345): WARNING **: Entity http://pcisig.com/pci/1af4/1058 referenced but not defined
virt-v2v: This guest has virtio drivers installed.
[ 129.9] Mapping filesystem data to avoid copying unused and blank areas
[ 146.9] Closing the overlay
[ 147.2] Assigning disks to buses
[ 147.2] Checking if the guest needs BIOS or UEFI to boot
[ 147.2] Setting up the destination: -o openstack -oo server-id=conversion-appliance
[ 207.7] Copying disk 1/5
█ 100% [****************************************]
[ 277.8] Copying disk 2/5
█ 100% [****************************************]
[ 406.4] Copying disk 3/5
█ 100% [****************************************]
[1027.2] Copying disk 4/5
█ 100% [****************************************]
[1073.7] Copying disk 5/5
█ 100% [****************************************]
[1084.3] Creating output metadata
[1093.8] Finishing off
```

### Output Explanation

- **Setting up the source**: Initializes the connection to the VMware source.
- **Opening the source**: Establishes a session with the vCenter server.
- **Inspecting the source**: Gathers information about the source VM, including OS type and installed drivers.
- **Converting \[Operating System\] to run on KVM**: Adapts the VM to be compatible with KVM hypervisor requirements.
- **Warnings and Notices**: Any warnings (like undefined entities) are displayed but can often be ignored.
- **Mapping filesystem data**: Optimizes data transfer by skipping unused disk space.
- **Copying disks**: Each disk is copied to a corresponding Cinder volume in OpenStack.
- **Creating output metadata**: Generates necessary metadata for the converted VM.
- **Finishing off**: Completes the conversion process.

## Handling Cinder Volumes Post-Conversion

After the conversion, **virt-v2v** creates Cinder volumes attached to the Conversion Appliance. These volumes represent the original disks of the source VM. The next step is to use these volumes to create a new OpenStack instance.

### Listing the Attached Volumes

To list the volumes attached to the Conversion Appliance, use the following command:

```bash
openstack volume list |grep conversion-appliance
```

Example output:

```plaintext
+--------------------------------------+--------------------+--------+------+----------------------------------------------+
| ID                                   | Name               | Status | Size | Attached to                                  |
+--------------------------------------+--------------------+--------+------+----------------------------------------------+
| 0cd29967-c21f-42a1-a513-9da4facc0606 | volume-0-SourceVM  | in-use | 100  | Attached to conversion-appliance on /dev/vdb |
| b2362093-ee1a-4a05-a0bb-21028595b73a | volume-1-SourceVM  | in-use | 200  | Attached to conversion-appliance on /dev/vdc |
| ea3b20ab-1e66-442d-9fdf-5e39c2c0f152 | volume-2-SourceVM  | in-use | 300  | Attached to conversion-appliance on /dev/vdd |
| bf11879b-76d1-466c-ae92-9c8ebd2e8d84 | volume-3-SourceVM  | in-use | 400  | Attached to conversion-appliance on /dev/vde |
| 75f510cd-af64-4264-9664-a0a863295167 | volume-4-SourceVM  | in-use | 500  | Attached to conversion-appliance on /dev/vdf |
+--------------------------------------+--------------------+--------+------+----------------------------------------------+
```

### Detaching the Volumes

Detach the volumes from the Conversion Appliance using the following command for each volume:

```bash
openstack server remove volume conversion-appliance <volume-id>
```

Replace `<volume-id>` with the actual ID of each volume.

### Creating a New Instance with the Converted Volumes

Now, create a new OpenStack instance using these volumes:

```bash
openstack server create \
  --flavor your-flavor \
  --volume volume-0-SourceVM \
  --block-device source_type=volume,uuid=b2362093-ee1a-4a05-a0bb-21028595b73a,destination_type=volume,boot_index=1 \
  --block-device source_type=volume,uuid=ea3b20ab-1e66-442d-9fdf-5e39c2c0f152,destination_type=volume,boot_index=2 \
  --block-device source_type=volume,uuid=bf11879b-76d1-466c-ae92-9c8ebd2e8d84,destination_type=volume,boot_index=3 \
  --block-device source_type=volume,uuid=75f510cd-af64-4264-9664-a0a863295167,destination_type=volume,boot_index=4 \
  --network your-network \
  --security-group your-security-group \
  SourceVM
```

**Note**: Replace `your-flavor`, `your-network`, `your-security-group`, and the volume UUIDs with your actual OpenStack resources.

In this command:

- The `--volume` option specifies the boot volume (`volume-0-SourceVM`) for the instance.
- The `--block-device` options attach the additional volumes to the instance, matching the original disk configuration of the source VM.

### Diagram: Creating a New VM from Cinder Volumes

Below is a diagram illustrating the steps to create a new VM from the converted volumes, using the disk names from the example:

```plaintext
         Steps                                  Actions and Components

Step 1: Start VM Creation           +---------------------------------------+
                                    |         OpenStack CLI                 |
                                    |                                       |
                                    |      openstack server create          |
                                    +---------------------------------------+

                                             |
                                             v

Step 2: Specify Boot Volume          +-----------------------------------+
                                     |           Boot Disk               |
                                     |   volume-0-SourceVM               |
                                     | (ID: 0cd29967-c21f-42a1-a513-...) |
                                     +-----------------------------------+

                                             |
                                             v

Step 3: Attach Supplementary          +-----------------------------------+
        Volumes                       |      Supplementary Disk 1         |
                                      |   volume-1-SourceVM               |
                                      | (ID: b2362093-ee1a-4a05-a0bb-...) |
                                      +-----------------------------------+
                                             |
                                             v
                                      +-----------------------------------+
                                      |      Supplementary Disk 2         |
                                      |   volume-2-SourceVM               |
                                      | (ID: ea3b20ab-1e66-442d-9fdf-...) |
                                      +-----------------------------------+
                                             |
                                             v
                                      +-----------------------------------+
                                      |      Supplementary Disk 3         |
                                      |   volume-3-SourceVM               |
                                      | (ID: bf11879b-76d1-466c-ae92-...) |
                                      +-----------------------------------+
                                             |
                                             v
                                      +-----------------------------------+
                                      |      Supplementary Disk 4         |
                                      |   volume-4-SourceVM               |
                                      | (ID: 75f510cd-af64-4264-9664-...) |
                                      +-----------------------------------+

                                             |
                                             v

Step 4: Complete VM Creation          +-----------------------------------+
                                      |           New VM in OpenStack     |
                                      |     (Replica of SourceVM)         |
                                      +-----------------------------------+
```

### Explanation of the Diagram

- **Step 1: Start VM Creation**
  - Use the `openstack server create` command to initiate the creation of a new instance.
- **Step 2: Specify Boot Volume**
  - Set `volume-0-SourceVM` as the boot disk using the `--volume` option.
  - **Boot Disk Details**:
    - Name: `volume-0-SourceVM`
    - ID: `0cd29967-c21f-42a1-a513-9da4facc0606`
- **Step 3: Attach Supplementary Volumes**
  - Attach additional volumes using the `--block-device` option for each supplementary disk.
  - **Supplementary Disk 1**:
    - Name: `volume-1-SourceVM`
    - ID: `b2362093-ee1a-4a05-a0bb-21028595b73a`
  - **Supplementary Disk 2**:
    - Name: `volume-2-SourceVM`
    - ID: `ea3b20ab-1e66-442d-9fdf-5e39c2c0f152`
  - **Supplementary Disk 3**:
    - Name: `volume-3-SourceVM`
    - ID: `bf11879b-76d1-466c-ae92-9c8ebd2e8d84`
  - **Supplementary Disk 4**:
    - Name: `volume-4-SourceVM`
    - ID: `75f510cd-af64-4264-9664-a0a863295167`
- **Step 4: Complete VM Creation**
  - Finalize the creation of the new VM, which now replicates the disk configuration of the original VMware VM.

