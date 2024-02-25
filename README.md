# 86-DOS 0.11 Source Code Reconstruction
Full source code reconstruction of 86-DOS 0.11 - the earliest released version of the earliest operating system for the Intel x86 architecture.

## Author
This software was written by [@TimPaterson](https://github.com/TimPaterson) in 1980. The reconstructed source code in this repository compiles back to the exact same binaries shipped by Seattle Computer Products. Therefore, it can be fully regrded as Paterson's work.

> [!IMPORTANT]
> Please do not file feature requests or make pull requests to fix bugs in the code. This is not my OS and I want this important piece of digital computing history to be preserved in its most original state. I will not accept anything that alters the assembled binaries in any way, shape or form.

## Disclaimer
This source code reconstruction is a product of reverse engineering. It is important to note that Microsoft Corporation has not released the source code for this specific version of DOS, and its legality may be in a gray area.

The source code reconstruction was undertaken with the understanding that Microsoft Corporation has open-sourced later versions of this operating system under the name MS-DOS, under the MIT License. The intention behind this source code reconstruction project is purely for historical and educational purposes, with a focus on preserving the heritage of early computing.

While efforts have been made to ensure compliance with applicable laws and regulations, the legal status of this source code reconstruction project may not be entirely clear. Users are advised to exercise caution and seek legal advice before using or redistributing any code extracted from this repository.

This project acknowledges the intellectual property rights of Microsoft Corporation and does not seek to infringe upon any proprietary rights. The reconstructed source code is shared in the spirit of historical preservation, education, and appreciation for this wonderful operating system.

By accessing and using the reconstructed source code provided in this repository, you agree to do so at your own risk and assume all responsibility for any legal implications that may arise.

## Building
All source files must be built using Seattle Computer Products' ASM-86 assembler. According to binary fragments found in the uninitialized data areas of executables, this version of 86-DOS was originally built under CP/M-80 2.2. However, since the CP/M-80 version of ASM-86 is not available online, the source files can only be assembled under DOS or Windows using the DOS version of ASM-86, branded simply as ASM. All assembly language source files in this repository use the extension <code>.ASM</code> so that they are accepted by the ASM assembler. Should a CP/M-80 version of ASM-86 surface one day, and if these files are to be built under CP/M, the extensions of the source files must be changed to <code>.A86</code>.

### Source to Object
To assemble a source file, invoke ASM with the command line:

<code>ASM \<source-file-name\></code>

Where \<source-file-name\> is the file name (without extension) of the <code>.ASM</code> source file. It will automatically produce the files <code>\<source-file-name\>.HEX</code> and <code>\<source-file-name\>.PRN</code> - the object code in Intel HEX format and the listing file, respectively. It is possible to disable the listing file, please refer to the ASM-86 manual for that.

### Object to Binary
To convert an object file to a binary executable, invoke HEX2BIN with the command line:

<code>HEX2BIN \<object-file-name\></code>

Where \<object-file-name\> is the file name (without extension) of the <code>.HEX</code> object file. It will automatically produce the binary file <code>\<object-file-name\>.COM</code>.

> [!NOTE]
> All source files must end with the byte <code>0x1A</code> (EOF marker) and be padded to the nearest 128 bytes. This requirement exists because early versions of 86-DOS behaved similarly to CP/M, storing files in terms of 128-byte records instead of individual bytes.<br><br>
> While the SCP ASM assembler can run under MS-DOS and 32-bit Windows, it is recommended that you use 86-DOS 0.11 itself to modify and assemble the source files, in adherence to the aforementioned requirements.

## Special Thanks
* [@TimPaterson](https://github.com/TimPaterson) - For writing this amazing OS.
* [@geneb](https://github.com/geneb) - For providing a copy of 86-DOS 0.11.
* [@LucasBrooks](https://github.com/LucasBrooks) - For providing an 86-DOS 1.14 kernel disassembly and for documenting the DPB structure.
* [@RichCini](https://github.com/RichCini) - For figuring out some hard-to-decipher logic and for testing and debugging the reconstructed Tarbell-specific code on physical hardware.
