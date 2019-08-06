# Starting a process

我们之前提到过，简单地说程序以 main（）函数开头并不完全正确。下面我们来看一下典型的动态链接程序在加载和运行时会发生什么（静态链接程序类似但不同的 XXX 应该进入这个？）。

首先，在响应 exec 系统调用时，内核为新进程分配结构并读取从磁盘指定的 ELF 文件。

我们提到 ELF 有一个程序解释器字段 PT_INTERP，可以设置为“解释”程序。对于动态链接的应用程序，解释器是动态链接器，即 ld.so，它允许一些链接过程在程序启动之前即时完成。

在这种情况下，内核还会读入动态链接器代码，并从其指定的入口点地址启动程序。我们将在下一章深入研究动态链接器的作用，但足以说它会进行一些设置，比如加载应用程序所需的任何库（如二进制文件的动态部分所指定），然后开始执行程序二进制文件在其入口点地址（即`_init`函数）。

## Kernel communication to programs

内核在启动时需要向程序传达一些内容;即程序的参数，当前环境变量和称为辅助向量或辅助的特殊结构(Auxiliary Vector or auxv)（您可以通过指定环境值 LD_SHOW_AUXV = 1 来请求动态链接器显示辅助的一些调试输出）。

相当直接的参数和环境，以及 exec 系统调用的各种化身允许您为程序指定这些参数和环境。

内核通过将所有必需信息放在堆栈中来为新创建的程序提取信息来进行通信。因此，当程序启动时，它可以使用其堆栈指针来查找所需的所有启动信息。

辅助向量(auxiliary vector)是一种特殊结构，用于将信息直接从内核传递到新运行的程序。它包含可能需要的系统特定信息，例如系统上虚拟内存页面的默认大小或硬件功能;这是内核已经识别出底层硬件的特定功能，用户空间程序可以利用这些功能。

### Kernel Library

我们之前提到系统调用很慢，现代系统有机制来避免调用陷阱到处理器的开销。

在 Linux 中，这是通过动态加载器和内核之间的巧妙技巧实现的，所有这些都与 AUXV 结构进行通信。内核实际上将一个小的共享库添加到每个新创建的进程的地址空间中，该进程包含一个为您调用系统的函数。该系统的优点在于，如果底层硬件支持快速系统调用机制，则内核（作为库的创建者）可以使用它，否则它可以使用生成陷阱的旧方案。这个库名为 linux-gate.so.1，因为它是内核内部工作的网关而被调用。

当内核启动动态链接器时，它会向 auxv 中添加一个名为 AT_SYSINFO_EHDR 的条目，该条目是特殊内核库所在的内存中的地址。当动态链接器启动时，它可以查找 `AT_SYSINFO_EHDR` 指针，如果找到则加载该库对于该计划。该程序不知道这个库存在;这是动态链接器和内核之间的私有安排。

我们提到程序员通过系统库中的调用函数间接进行系统调用，即 libc。 libc 可以检查是否加载了特殊内核二进制文件，如果是，则使用其中的函数进行系统调用。正如我们所提到的，如果内核确定硬件能够，则将使用快速系统调用方法。

## Starting the program

一旦内核加载了解释器，它就会将它传递给解释器文件中给出的入口点（注意不会检查动态链接器在此阶段的启动方式;有关动态链接的完整讨论，请参阅第 9 章动态链接）。 动态链接器将跳转到 ELF 二进制文件中给出的入口点地址。

Disassembley of program startup:

```
    $ cat test.c

    int main(void)
    {
    	return 0;
    }

    $ gcc -o test test.c

    $ readelf --headers ./test | grep Entry
      Entry point address:               0x80482b0

    $ objdump --disassemble ./test

    [...]

    080482b0 <_start>:
     80482b0:       31 ed                   xor    %ebp,%ebp
     80482b2:       5e                      pop    %esi
     80482b3:       89 e1                   mov    %esp,%ecx
     80482b5:       83 e4 f0                and    $0xfffffff0,%esp
     80482b8:       50                      push   %eax
     80482b9:       54                      push   %esp
     80482ba:       52                      push   %edx
     80482bb:       68 00 84 04 08          push   $0x8048400
     80482c0:       68 90 83 04 08          push   $0x8048390
     80482c5:       51                      push   %ecx
     80482c6:       56                      push   %esi
     80482c7:       68 68 83 04 08          push   $0x8048368
     80482cc:       e8 b3 ff ff ff          call   8048284 <__libc_start_main@plt>
     80482d1:       f4                      hlt
     80482d2:       90                      nop
     80482d3:       90                      nop

    08048368 <main>:
     8048368:       55                      push   %ebp
     8048369:       89 e5                   mov    %esp,%ebp
     804836b:       83 ec 08                sub    $0x8,%esp
     804836e:       83 e4 f0                and    $0xfffffff0,%esp
     8048371:       b8 00 00 00 00          mov    $0x0,%eax
     8048376:       83 c0 0f                add    $0xf,%eax
     8048379:       83 c0 0f                add    $0xf,%eax
     804837c:       c1 e8 04                shr    $0x4,%eax
     804837f:       c1 e0 04                shl    $0x4,%eax
     8048382:       29 c4                   sub    %eax,%esp
     8048384:       b8 00 00 00 00          mov    $0x0,%eax
     8048389:       c9                      leave
     804838a:       c3                      ret
     804838b:       90                      nop
     804838c:       90                      nop
     804838d:       90                      nop
     804838e:       90                      nop
     804838f:       90                      nop

    08048390 <__libc_csu_init>:
     8048390:       55                      push   %ebp
     8048391:       89 e5                   mov    %esp,%ebp
     [...]

    08048400 <__libc_csu_fini>:
     8048400:       55                      push   %ebp
     [...]
```

上面我们调查最简单的程序。使用 readelf，我们可以看到入口点是二进制文件中的`_start` 函数。此时我们可以在反汇编中看到一些值被压入堆栈。第一个值 0x8048400 是`__libc_csu_fini`函数; 0x8048390 是`__libc_csu_init`，最后是 0x8048368，main（）函数。在此之后调用值`__libc_start_main`函数。

`__libc_start_main`在`glibc sources sysdeps / generic / libc-start.c`中定义。文件功能非常复杂，并且隐藏在大量定义之间，因为它需要可以在 glibc 可以运行的大量系统和体系结构中移植。它做了很多与设置 C 库相关的具体事情，普通程序员不需要担心。库调用程序的下一个点是处理 init 代码。

init 和 fini 是两个特殊的概念，它们调用共享库中的部分代码，这些代码可能需要在库启动之前调用，或者分别卸载库。您可以看到这对于库程序员在启动库时设置变量或者最后清理时如何有用。最初在库中查找函数`_init`和`_fini`;然而，这变得有些限制，因为一切都需要在这些功能中。下面我们将研究`init / fini`过程的工作原理。

在这个阶段，我们可以看到`__libc_start_main`函数将在堆栈上接收相当多的输入参数。首先，它可以从内核访问程序参数，环境变量和辅助向量。然后，初始化函数将推入堆栈地址，以便函数处理 init，fini，最后处理 main 函数本身的地址。

我们需要一些方法在源代码中指出函数应该由 init 或 fini 调用。使用 gcc，我们使用属性将两个函数标记为主程序中的构造函数和析构函数。这些术语更常用于面向对象的语言来描述对象生命周期。

Constructors and Destructors:

```
1 $ cat test.c
    #include <stdio.h>

    void __attribute__((constructor)) program_init(void)  {
  5   printf("init\n");
    }

    void  __attribute__((destructor)) program_fini(void) {
      printf("fini\n");
 10 }

    int main(void)
    {
      return 0;
 15 }

    $ gcc -Wall  -o test test.c

    $ ./test
 20 init
    fini

    $ objdump --disassemble ./test | grep program_init
    08048398 <program_init>:
 25
    $ objdump --disassemble ./test | grep program_fini
    080483b0 <program_fini>:

    $ objdump --disassemble ./test
 30
    [...]
    08048280 <_init>:
     8048280:       55                      push   %ebp
     8048281:       89 e5                   mov    %esp,%ebp
 35  8048283:       83 ec 08                sub    $0x8,%esp
     8048286:       e8 79 00 00 00          call   8048304 <call_gmon_start>
     804828b:       e8 e0 00 00 00          call   8048370 <frame_dummy>
     8048290:       e8 2b 02 00 00          call   80484c0 <__do_global_ctors_aux>
     8048295:       c9                      leave
 40  8048296:       c3                      ret
    [...]

    080484c0 <__do_global_ctors_aux>:
     80484c0:       55                      push   %ebp
 45  80484c1:       89 e5                   mov    %esp,%ebp
     80484c3:       53                      push   %ebx
     80484c4:       52                      push   %edx
     80484c5:       a1 2c 95 04 08          mov    0x804952c,%eax
     80484ca:       83 f8 ff                cmp    $0xffffffff,%eax
 50  80484cd:       74 1e                   je     80484ed <__do_global_ctors_aux+0x2d>
     80484cf:       bb 2c 95 04 08          mov    $0x804952c,%ebx
     80484d4:       8d b6 00 00 00 00       lea    0x0(%esi),%esi
     80484da:       8d bf 00 00 00 00       lea    0x0(%edi),%edi
     80484e0:       ff d0                   call   *%eax
 55  80484e2:       8b 43 fc                mov    0xfffffffc(%ebx),%eax
     80484e5:       83 eb 04                sub    $0x4,%ebx
     80484e8:       83 f8 ff                cmp    $0xffffffff,%eax
     80484eb:       75 f3                   jne    80484e0 <__do_global_ctors_aux+0x20>
     80484ed:       58                      pop    %eax
 60  80484ee:       5b                      pop    %ebx
     80484ef:       5d                      pop    %ebp
     80484f0:       c3                      ret
     80484f1:       90                      nop
     80484f2:       90                      nop
 65  80484f3:       90                      nop


    $ readelf --sections ./test
    There are 34 section headers, starting at offset 0xfb0:
 70
    Section Headers:
      [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al
      [ 0]                   NULL            00000000 000000 000000 00      0   0  0
      [ 1] .interp           PROGBITS        08048114 000114 000013 00   A  0   0  1
 75   [ 2] .note.ABI-tag     NOTE            08048128 000128 000020 00   A  0   0  4
      [ 3] .hash             HASH            08048148 000148 00002c 04   A  4   0  4
      [ 4] .dynsym           DYNSYM          08048174 000174 000060 10   A  5   1  4
      [ 5] .dynstr           STRTAB          080481d4 0001d4 00005e 00   A  0   0  1
      [ 6] .gnu.version      VERSYM          08048232 000232 00000c 02   A  4   0  2
 80   [ 7] .gnu.version_r    VERNEED         08048240 000240 000020 00   A  5   1  4
      [ 8] .rel.dyn          REL             08048260 000260 000008 08   A  4   0  4
      [ 9] .rel.plt          REL             08048268 000268 000018 08   A  4  11  4
      [10] .init             PROGBITS        08048280 000280 000017 00  AX  0   0  4
      [11] .plt              PROGBITS        08048298 000298 000040 04  AX  0   0  4
 85   [12] .text             PROGBITS        080482e0 0002e0 000214 00  AX  0   0 16
      [13] .fini             PROGBITS        080484f4 0004f4 00001a 00  AX  0   0  4
      [14] .rodata           PROGBITS        08048510 000510 000012 00   A  0   0  4
      [15] .eh_frame         PROGBITS        08048524 000524 000004 00   A  0   0  4
      [16] .ctors            PROGBITS        08049528 000528 00000c 00  WA  0   0  4
 90   [17] .dtors            PROGBITS        08049534 000534 00000c 00  WA  0   0  4
      [18] .jcr              PROGBITS        08049540 000540 000004 00  WA  0   0  4
      [19] .dynamic          DYNAMIC         08049544 000544 0000c8 08  WA  5   0  4
      [20] .got              PROGBITS        0804960c 00060c 000004 04  WA  0   0  4
      [21] .got.plt          PROGBITS        08049610 000610 000018 04  WA  0   0  4
 95   [22] .data             PROGBITS        08049628 000628 00000c 00  WA  0   0  4
      [23] .bss              NOBITS          08049634 000634 000004 00  WA  0   0  4
      [24] .comment          PROGBITS        00000000 000634 00018f 00      0   0  1
      [25] .debug_aranges    PROGBITS        00000000 0007c8 000078 00      0   0  8
      [26] .debug_pubnames   PROGBITS        00000000 000840 000025 00      0   0  1
100   [27] .debug_info       PROGBITS        00000000 000865 0002e1 00      0   0  1
      [28] .debug_abbrev     PROGBITS        00000000 000b46 000076 00      0   0  1
      [29] .debug_line       PROGBITS        00000000 000bbc 0001da 00      0   0  1
      [30] .debug_str        PROGBITS        00000000 000d96 0000f3 01  MS  0   0  1
      [31] .shstrtab         STRTAB          00000000 000e89 000127 00      0   0  1
105   [32] .symtab           SYMTAB          00000000 001500 000490 10     33  53  4
      [33] .strtab           STRTAB          00000000 001990 000218 00      0   0  1
    Key to Flags:
      W (write), A (alloc), X (execute), M (merge), S (strings)
      I (info), L (link order), G (group), x (unknown)
110   O (extra OS processing required) o (OS specific), p (processor specific)

    $ objdump --disassemble-all --section .ctors ./test

    ./test:     file format elf32-i386
115
    Contents of section .ctors:
     8049528 ffffffff 98830408 00000000           ............

```

推送到`__libc_start_main`的堆栈的最后一个值是初始化函数`__libc_csu_init`。如果我们从`__libc_csu_init`跟随调用链，我们可以看到它进行了一些设置，然后调用可执行文件中的`_init`函数。 `_init`函数最终调用一个名为`__do_global_ctors_aux`的函数。看看这个函数的反汇编，我们可以看到它似乎从地址 0x804952c 开始并循环，读取一个值并调用它。我们可以看到这个起始地址位于文件的.ctors 部分;如果我们看一下这里，我们看到它包含第一个值-1，一个函数地址（大端格式）和零值。

big endian 格式的地址是 0x08048398，或者是 program_init 函数的地址！因此.ctors 部分的格式首先是-1，然后是初始化时要调用的函数的地址，最后是零以表示列表已完成。将调用每个条目（在这种情况下，我们只有一个函数）。

一旦`__libc_start_main`完成`_init`调用，它最终调用 main（）函数！请记住，它最初使用来自内核的参数和环境指针进行堆栈设置;这就是 main 如何得到它的 argc，argv []，envp []参数。现在，该过程已运行，设置阶段已完成。

当程序退出时，类似的过程与.dtors 一起用于析构函数。 `__libc_start_main`在 main（）函数完成时调用它们。

正如您所看到的，在程序开始之前已经完成了很多工作，甚至在您认为完成之后还有一些工作！
