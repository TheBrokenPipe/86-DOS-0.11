# CP/M Building Tools
This folder contains some of the Z80 tools required for building and deploying 86-DOS 0.11 under CP/M (or Cromemco CDOS, the operating system [@TimPaterson](https://github.com/TimPaterson) used). You will need these if you wish to create a working copy of 86-DOS 0.11 from pure source code.

> [!WARNING]
> These tools have only been tested under Cromemco CDOS 2.x. There is no guarantee that they will work under the official CP/M operating system or other CP/M-like operating systems. The source files are to be assembled using Cromemco's CDOS Z80 assembler, and you must have a Z80 CPU to run the binaries.

## ASM86
This is a reconstruction of the SCP Z80/8086 Cross Assembler [@TimPaterson](https://github.com/TimPaterson) used to develop 86-DOS. Original copies of this cross assembler are long gone, and the only thing we have now is [a manual](https://bitsavers.org/pdf/seattleComputer/Z80_8086_Cross_Assembler_Preliminary.pdf) for it. Given that the 86-DOS <code>ASM</code> assembler is essentially an 8086 translation of this assembler, I wrote a utility that does the exact opposite of <code>TRANS</code> (named CIS) to translate 86-DOS 0.11's assembler back to Z80. After making some minor tweaks to the output, I was able to make it work, so here it is.

> [!TIP]
> The Z80 source of the assembler is actually easier to read than the 8086 source because this assembler was originally written in the Z80 assembly language. When it was translated to 8086, a lot of boilerplate code were added, which made the code slightly difficult to follow. Now that it has been translated back to Z80, those boilerplate code have been removed.

ASM86 takes the following parameters: <code>[x:]ASM86 [y:]name[.ijk] [S]</code>

where

<table>
    <colgroup>
        <col style="width: 15%;">
        <col style="width: 85%;">
    </colgroup>
    <tbody>
        <tr>
            <td>x</td>
            <td>is an optional disk drive specifier indicating the location of the <code>ASM86.COM</code> file. This parameter is required only if the COM file is <u>NOT</u> located on either drive A or the current drive. Legal values are A, B, C, and D.</td>
        </tr>
        <tr>
            <td>y</td>
            <td>is an optional disk drive specifier indicating the location of the source file. This paramter may be omitted if the source file is on the current drive.</td>
        </tr>
        <tr>
            <td>name</td>
            <td>is the name of the 8086 assembly language source file, without the 3-letter extension. The extension <code>A86</code> is always assumed and may not be overriden.</td>
        </tr>
        <tr>
            <td>ijk</td>
            <td>is an optional 3-letter drive assigment parameter. The first letter is the name of the drive on which the source file will be found. This overrides a disk specifier which precedes the file name. The second letter is the name of the drive to which the hex object file will be written, or <code>Z</code> if no object file is desired. The third letter is the name of the drive to which the listing file will be written, or <code>X</code> to send the listing to the console, or <code>Z</code> if no listing file is desired. Assembling with no listing is much faster since the source file will not be read from disk a second time.</td>
        </tr>
        <tr>
            <td><code>S</code></td>
            <td>is an optional switch indicating that a symbol table is to be placed at the end of the listing.</td>
        </tr>
    </tbody>
</table>

This assembler can only produce Intel HEX files for object code, therefore you must convert them to binary before they can be executed on the 8086. Under CP/M, this can be done using the <code>LOAD</code> command. If you are using CDOS, which does not have <code>LOAD</code>, you will have to use <code>DEBUG</code> to load the .HEX file to memory and <code>SAVE</code> to save the loaded pages as a disk file.

> [!TIP]
> Don't forget to rename the source files from <code>.ASM</code> to <code>.A86</code>.

## TRANS86
This is a reconstruction of the SCP Z80 to 8086 Translator shipped together with ASM86. Like ASM86, original copies are long gone and this is the 8086 version from 86-DOS 0.11 translated back to Z80.

TRANS86 takes the following parameters: <code>[x:]TRANS86 [y:]name.ext</code>

where

<table>
    <colgroup>
        <col style="width: 15%;">
        <col style="width: 85%;">
    </colgroup>
    <tbody>
        <tr>
            <td>x</td>
            <td>is an optional disk drive specifier indicating the location of the <code>TRANS86.COM</code> file. This parameter is required only if the COM file is <u>NOT</u> located on either drive A or the current drive. Legal values are A, B, C, and D.</td>
        </tr>
        <tr>
            <td>y</td>
            <td>is an optional disk drive specifier indicating the location of the Z80 source file. This paramter may be omitted if the source file is on the current drive.</td>
        </tr>
        <tr>
            <td>name.ext</td>
            <td>is the name of the Z80 assembly language source file, with the 3-letter extension.</td>
        </tr>
    </tbody>
</table>

The output 8086 source file will have the same name as the Z80 source file, but with the extension .A86.

## DOSGEN
This is a tool I wrote to copy 86-DOS system files to the system area of IBM 8" SSSD floppies. It works in a similar way to CP/M's <code>SYSGEN</code> utility.

DOSGEN takes the following parameters: <code>[x:]DOSGEN y: [N]</code>

where

<table>
    <colgroup>
        <col style="width: 15%;">
        <col style="width: 85%;">
    </colgroup>
    <tbody>
        <tr>
            <td>x</td>
            <td>is an optional disk drive specifier indicating the location of the <code>DOSGEN.COM</code> file. This parameter is required only if the COM file is <u>NOT</u> located on either drive A or the current drive. Legal values are A, B, C, and D.</td>
        </tr>
        <tr>
            <td>y</td>
            <td>is a disk drive specifier indicating the disk upon which the 86-DOS system is to be written.</td>
        </tr>
        <tr>
            <td><code>N</code></td>
            <td>is an optional switch indicating that a new file system is to be put on the destination disk. If this switch is specified, a file system with the files <code>COMMAND.COM</code> and <code>RDCPM.COM</code> will be written alongside the system.</td>
        </tr>
    </tbody>
</table>

 To copy 86-DOS to a new floppy disk, you must have the files <code>BOOT.COM</code>, <code>DOSIO.COM</code> and <code>86DOS.COM</code> on the current drive. If a new file system is to be created, <code>COMMAND.COM</code> and <code>RDCPM.COM</code> must also exist.
