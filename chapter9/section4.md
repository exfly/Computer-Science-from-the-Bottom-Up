# Libraries

## The Procedure Lookup Table

库可能包含许多功能，程序最终可能包含许多库以完成其工作。程序可能只使用许多可用的每个库中的一个或两个函数，并且根据代码的运行时路径可能使用某些函数而不是其他函数。

正如我们所看到的，动态链接的过程是一个计算密集型的过程，因为它涉及查找和搜索许多表。任何可以减少开销的事情都会提高性能。

过程查找表（PLT）促进了程序中所谓的延迟绑定。绑定与上面针对位于 GOT 中的变量描述的修复过程同义。当一个条目被“修复”时，它被称为“绑定”到它的真实地址。

正如我们所提到的，有时一个程序将包含一个来自库的函数，但实际上根本不会调用该函数，具体取决于用户输入。绑定此函数的过程非常密集，包括加载代码，搜索表和写入内存。完成绑定未使用的函数的过程只是浪费时间。

延迟绑定延迟了这笔费用，直到使用 PLT 调用实际函数。

每个库函数在 PLT 中都有一个条目，它最初指向一些特殊的伪代码。当程序调用该函数时，它实际调用 PLT 条目（与通过 GOT 引用的变量相同）。

这个虚函数将加载一些需要传递给动态链接器的参数，以便它解析函数，然后调用动态链接器的特殊查找函数。动态链接器查找函数的实际地址，并将该位置写入虚函数调用顶部的调用二进制文件中。

因此，下次调用该函数时，可以加载地址而无需再次返回动态加载程序。如果永远不调用函数，那么 PLT 条目将永远不会被修改，但不会有运行时开销。

## The PLT in action

事情开始变得有点复杂了！ 如果没有别的，你应该开始意识到解决动态符号还有很多工作要做！

让我们考虑一下简单的“hello World”应用程序。 这只会使一个库调用 printf 将字符串输出给用户。

```
    $ cat hello.c
    #include <stdio.h>

    int main(void)
    {
            printf("Hello, World!\n");
            return 0;
    }

    $ gcc -o hello hello.c

    $ readelf --relocs ./hello

    Relocation section '.rela.dyn' at offset 0x3f0 contains 2 entries:
      Offset          Info           Type           Sym. Value    Sym. Name + Addend
    6000000000000ed8  000700000047 R_IA64_FPTR64LSB  0000000000000000 _Jv_RegisterClasses + 0
    6000000000000ee0  000900000047 R_IA64_FPTR64LSB  0000000000000000 __gmon_start__ + 0

    Relocation section '.rela.IA_64.pltoff' at offset 0x420 contains 3 entries:
      Offset          Info           Type           Sym. Value    Sym. Name + Addend
    6000000000000f10  000200000081 R_IA64_IPLTLSB    0000000000000000 printf + 0
    6000000000000f20  000800000081 R_IA64_IPLTLSB    0000000000000000 __libc_start_main + 0
    6000000000000f30  000900000081 R_IA64_IPLTLSB    0000000000000000 __gmon_start__ + 0
```

我们可以看到上面的 printf 符号有一个 R_IA64_IPLTLSB 重定位。 这就是说“将符号 printf 的地址放入存储器地址 0x6000000000000f10”。 我们必须开始深入挖掘，找到让我们获得功能的确切程序。

下面我们来看看程序的 main（）函数的反汇编。

```
    4000000000000790 <main>:
    4000000000000790:       00 08 15 08 80 05       [MII]       alloc r33=ar.pfs,5,4,0
    4000000000000796:       20 02 30 00 42 60                   mov r34=r12
    400000000000079c:       04 08 00 84                         mov r35=r1
    40000000000007a0:       01 00 00 00 01 00       [MII]       nop.m 0x0
    40000000000007a6:       00 02 00 62 00 c0                   mov r32=b0
    40000000000007ac:       81 0c 00 90                         addl r14=72,r1;;
    40000000000007b0:       1c 20 01 1c 18 10       [MFB]       ld8 r36=[r14]
    40000000000007b6:       00 00 00 02 00 00                   nop.f 0x0
    40000000000007bc:       78 fd ff 58                         br.call.sptk.many b0=4000000000000520 <_init+0xb0>
    40000000000007c0:       02 08 00 46 00 21       [MII]       mov r1=r35
    40000000000007c6:       e0 00 00 00 42 00                   mov r14=r0;;
    40000000000007cc:       01 70 00 84                         mov r8=r14
    40000000000007d0:       00 00 00 00 01 00       [MII]       nop.m 0x0
    40000000000007d6:       00 08 01 55 00 00                   mov.i ar.pfs=r33
    40000000000007dc:       00 0a 00 07                         mov b0=r32
    40000000000007e0:       1d 60 00 44 00 21       [MFB]       mov r12=r34
    40000000000007e6:       00 00 00 02 00 80                   nop.f 0x0
    40000000000007ec:       08 00 84 00                         br.ret.sptk.many b0;;
```

对 0x4000000000000520 的调用必须是我们调用 printf 函数。 我们可以通过查看 readelf 的部分找到它的位置。

```
    $ readelf --sections ./hello
    There are 40 section headers, starting at offset 0x25c0:

    Section Headers:
      [Nr] Name              Type             Address           Offset
           Size              EntSize          Flags  Link  Info  Align
      [ 0]                   NULL             0000000000000000  00000000
           0000000000000000  0000000000000000           0     0     0
    ...
      [11] .plt              PROGBITS         40000000000004c0  000004c0
           00000000000000c0  0000000000000000  AX       0     0     32
      [12] .text             PROGBITS         4000000000000580  00000580
           00000000000004a0  0000000000000000  AX       0     0     32
      [13] .fini             PROGBITS         4000000000000a20  00000a20
           0000000000000040  0000000000000000  AX       0     0     16
      [14] .rodata           PROGBITS         4000000000000a60  00000a60
           000000000000000f  0000000000000000   A       0     0     8
      [15] .opd              PROGBITS         4000000000000a70  00000a70
           0000000000000070  0000000000000000   A       0     0     16
      [16] .IA_64.unwind_inf PROGBITS         4000000000000ae0  00000ae0
           00000000000000f0  0000000000000000   A       0     0     8
      [17] .IA_64.unwind     IA_64_UNWIND     4000000000000bd0  00000bd0
           00000000000000c0  0000000000000000  AL      12     c     8
      [18] .init_array       INIT_ARRAY       6000000000000c90  00000c90
           0000000000000018  0000000000000000  WA       0     0     8
      [19] .fini_array       FINI_ARRAY       6000000000000ca8  00000ca8
           0000000000000008  0000000000000000  WA       0     0     8
      [20] .data             PROGBITS         6000000000000cb0  00000cb0
           0000000000000004  0000000000000000  WA       0     0     4
      [21] .dynamic          DYNAMIC          6000000000000cb8  00000cb8
           00000000000001e0  0000000000000010  WA       5     0     8
      [22] .ctors            PROGBITS         6000000000000e98  00000e98
           0000000000000010  0000000000000000  WA       0     0     8
      [23] .dtors            PROGBITS         6000000000000ea8  00000ea8
           0000000000000010  0000000000000000  WA       0     0     8
      [24] .jcr              PROGBITS         6000000000000eb8  00000eb8
           0000000000000008  0000000000000000  WA       0     0     8
      [25] .got              PROGBITS         6000000000000ec0  00000ec0
           0000000000000050  0000000000000000 WAp       0     0     8
      [26] .IA_64.pltoff     PROGBITS         6000000000000f10  00000f10
           0000000000000030  0000000000000000 WAp       0     0     16
      [27] .sdata            PROGBITS         6000000000000f40  00000f40
           0000000000000010  0000000000000000 WAp       0     0     8
      [28] .sbss             NOBITS           6000000000000f50  00000f50
           0000000000000008  0000000000000000  WA       0     0     8
      [29] .bss              NOBITS           6000000000000f58  00000f50
           0000000000000008  0000000000000000  WA       0     0     8
      [30] .comment          PROGBITS         0000000000000000  00000f50
           00000000000000b9  0000000000000000           0     0     1
      [31] .debug_aranges    PROGBITS         0000000000000000  00001010
           0000000000000090  0000000000000000           0     0     16
      [32] .debug_pubnames   PROGBITS         0000000000000000  000010a0
           0000000000000025  0000000000000000           0     0     1
      [33] .debug_info       PROGBITS         0000000000000000  000010c5
           00000000000009c4  0000000000000000           0     0     1
      [34] .debug_abbrev     PROGBITS         0000000000000000  00001a89
           0000000000000124  0000000000000000           0     0     1
      [35] .debug_line       PROGBITS         0000000000000000  00001bad
           00000000000001fe  0000000000000000           0     0     1
      [36] .debug_str        PROGBITS         0000000000000000  00001dab
           00000000000006a1  0000000000000001  MS       0     0     1
      [37] .shstrtab         STRTAB           0000000000000000  0000244c
           000000000000016f  0000000000000000           0     0     1
      [38] .symtab           SYMTAB           0000000000000000  00002fc0
           0000000000000b58  0000000000000018          39    60     8
      [39] .strtab           STRTAB           0000000000000000  00003b18
           0000000000000479  0000000000000000           0     0     1
    Key to Flags:
      W (write), A (alloc), X (execute), M (merge), S (strings)
      I (info), L (link order), G (group), x (unknown)
      O (extra OS processing required) o (OS specific), p (processor specific)
```

该地址（不出所料）在.plt 部分。 所以我们打电话给 PLT！ 但我们对此并不满意，让我们继续深入挖掘，看看我们能发现什么。 我们反汇编.plt 部分以查看该调用实际上做了什么。

```
    40000000000004c0 <.plt>:
    40000000000004c0:       0b 10 00 1c 00 21       [MMI]       mov r2=r14;;
    40000000000004c6:       e0 00 08 00 48 00                   addl r14=0,r2
    40000000000004cc:       00 00 04 00                         nop.i 0x0;;
    40000000000004d0:       0b 80 20 1c 18 14       [MMI]       ld8 r16=[r14],8;;
    40000000000004d6:       10 41 38 30 28 00                   ld8 r17=[r14],8
    40000000000004dc:       00 00 04 00                         nop.i 0x0;;
    40000000000004e0:       11 08 00 1c 18 10       [MIB]       ld8 r1=[r14]
    40000000000004e6:       60 88 04 80 03 00                   mov b6=r17
    40000000000004ec:       60 00 80 00                         br.few b6;;
    40000000000004f0:       11 78 00 00 00 24       [MIB]       mov r15=0
    40000000000004f6:       00 00 00 02 00 00                   nop.i 0x0
    40000000000004fc:       d0 ff ff 48                         br.few 40000000000004c0 <_init+0x50>;;
    4000000000000500:       11 78 04 00 00 24       [MIB]       mov r15=1
    4000000000000506:       00 00 00 02 00 00                   nop.i 0x0
    400000000000050c:       c0 ff ff 48                         br.few 40000000000004c0 <_init+0x50>;;
    4000000000000510:       11 78 08 00 00 24       [MIB]       mov r15=2
    4000000000000516:       00 00 00 02 00 00                   nop.i 0x0
    400000000000051c:       b0 ff ff 48                         br.few 40000000000004c0 <_init+0x50>;;
    4000000000000520:       0b 78 40 03 00 24       [MMI]       addl r15=80,r1;;
    4000000000000526:       00 41 3c 70 29 c0                   ld8.acq r16=[r15],8
    400000000000052c:       01 08 00 84                         mov r14=r1;;
    4000000000000530:       11 08 00 1e 18 10       [MIB]       ld8 r1=[r15]
    4000000000000536:       60 80 04 80 03 00                   mov b6=r16
    400000000000053c:       60 00 80 00                         br.few b6;;
    4000000000000540:       0b 78 80 03 00 24       [MMI]       addl r15=96,r1;;
    4000000000000546:       00 41 3c 70 29 c0                   ld8.acq r16=[r15],8
    400000000000054c:       01 08 00 84                         mov r14=r1;;
    4000000000000550:       11 08 00 1e 18 10       [MIB]       ld8 r1=[r15]
    4000000000000556:       60 80 04 80 03 00                   mov b6=r16
    400000000000055c:       60 00 80 00                         br.few b6;;
    4000000000000560:       0b 78 c0 03 00 24       [MMI]       addl r15=112,r1;;
    4000000000000566:       00 41 3c 70 29 c0                   ld8.acq r16=[r15],8
    400000000000056c:       01 08 00 84                         mov r14=r1;;
    4000000000000570:       11 08 00 1e 18 10       [MIB]       ld8 r1=[r15]
    4000000000000576:       60 80 04 80 03 00                   mov b6=r16
    400000000000057c:       60 00 80 00                         br.few b6;;

```

让我们逐步完成说明。 首先，我们将 r1 中的值加 80，并将其存储在 r15 中。 我们从之前就知道 r1 将指向 GOT，所以这就是说“将 r15 80 字节存储到 GOT 中”。 接下来我们要做的是将存储在 GOT 中此位置的值加载到 r16，然后将 r15 中的值递增 8 个字节。 然后我们将 r1（GOT 的位置）存储在 r14 中，并将 r1 设置为 r15 之后的下一个 8 字节中的值。 然后我们分支到 r16。

在前一章中，我们讨论了如何通过函数描述符实际调用函数，函数描述符包含函数地址和全局指针的地址。 在这里我们可以看到 PLT 条目首先加载函数值，将 8 个字节移动到函数描述符的第二部分，然后在调用函数之前将该值加载到 op 寄存器中。

但究竟我们装的是什么？ 我们知道 r1 将指向 GOT。 我们超过了得到的 80 字节（0x50）

```
    $ objdump --disassemble-all ./hello
    Disassembly of section .got:

    6000000000000ec0 <.got>:
            ...
    6000000000000ee8:       80 0a 00 00 00 00                   data8 0x02a000000
    6000000000000eee:       00 40 90 0a                         dep r0=r0,r0,63,1
    6000000000000ef2:       00 00 00 00 00 40       [MIB] (p20) break.m 0x1
    6000000000000ef8:       a0 0a 00 00 00 00                   data8 0x02a810000
    6000000000000efe:       00 40 50 0f                         br.few 6000000000000ef0 <_GLOBAL_OFFSET_TABLE_+0x30>
    6000000000000f02:       00 00 00 00 00 60       [MIB] (p58) break.m 0x1
    6000000000000f08:       60 0a 00 00 00 00                   data8 0x029818000
    6000000000000f0e:       00 40 90 06                         br.few 6000000000000f00 <_GLOBAL_OFFSET_TABLE_+0x40>
    Disassembly of section .IA_64.pltoff:

    6000000000000f10 <.IA_64.pltoff>:
    6000000000000f10:       f0 04 00 00 00 00       [MIB] (p39) break.m 0x0
    6000000000000f16:       00 40 c0 0e 00 00                   data8 0x03b010000
    6000000000000f1c:       00 00 00 60                         data8 0xc000000000
    6000000000000f20:       00 05 00 00 00 00       [MII] (p40) break.m 0x0
    6000000000000f26:       00 40 c0 0e 00 00                   data8 0x03b010000
    6000000000000f2c:       00 00 00 60                         data8 0xc000000000
    6000000000000f30:       10 05 00 00 00 00       [MIB] (p40) break.m 0x0
    6000000000000f36:       00 40 c0 0e 00 00                   data8 0x03b010000
    6000000000000f3c:       00 00 00 60                         data8 0xc000000000
```

0x6000000000000ec0 + 0x50 = 0x6000000000000f10，或.IA_64.pltoff 部分。现在我们开始到达某个地方！

我们可以解码 objdump 输出，这样我们就可以看到这里正在加载的内容。交换前 8 个字节的字节顺序 f0 04 00 00 00 00 00 40 我们最终得到 0x4000000000004f0。那个地址看起来很熟悉！回顾一下 PLT 的汇编输出，我们看到了那个地址。

0x4000000000004f0 处的代码首先将零值置入 r15，然后分支回 0x40000000000004c0。等一下！这是我们 PLT 部分的开始。

我们也可以跟踪这段代码。首先我们保存全局指针（r2）的值，然后我们将三个 8 字节值加载到 r16，r17，最后加载到 r1。然后我们转到 r17 的地址。我们在这里看到的是对动态链接器的实际调用！

我们需要深入研究 ABI，以便准确了解此时正在加载的内容。 ABI 说两件事 - 动态链接程序必须有一个特殊部分（称为 DT_IA_64_PLT_RESERVE 部分），它可以容纳三个 8 字节值。在二进制的动态段中有一个指向保留区域的指针。

```
     Dynamic segment at offset 0xcb8 contains 25 entries:
      Tag        Type                         Name/Value
     0x0000000000000001 (NEEDED)             Shared library: [libc.so.6.1]
     0x000000000000000c (INIT)               0x4000000000000470
     0x000000000000000d (FINI)               0x4000000000000a20
     0x0000000000000019 (INIT_ARRAY)         0x6000000000000c90
     0x000000000000001b (INIT_ARRAYSZ)       24 (bytes)
     0x000000000000001a (FINI_ARRAY)         0x6000000000000ca8
     0x000000000000001c (FINI_ARRAYSZ)       8 (bytes)
     0x0000000000000004 (HASH)               0x4000000000000200
     0x0000000000000005 (STRTAB)             0x4000000000000330
     0x0000000000000006 (SYMTAB)             0x4000000000000240
     0x000000000000000a (STRSZ)              138 (bytes)
     0x000000000000000b (SYMENT)             24 (bytes)
     0x0000000000000015 (DEBUG)              0x0
     0x0000000070000000 (IA_64_PLT_RESERVE)  0x6000000000000ec0 -- 0x6000000000000ed8
     0x0000000000000003 (PLTGOT)             0x6000000000000ec0
     0x0000000000000002 (PLTRELSZ)           72 (bytes)
     0x0000000000000014 (PLTREL)             RELA
     0x0000000000000017 (JMPREL)             0x4000000000000420
     0x0000000000000007 (RELA)               0x40000000000003f0
     0x0000000000000008 (RELASZ)             48 (bytes)
     0x0000000000000009 (RELAENT)            24 (bytes)
     0x000000006ffffffe (VERNEED)            0x40000000000003d0
     0x000000006fffffff (VERNEEDNUM)         1
     0x000000006ffffff0 (VERSYM)             0x40000000000003ba
     0x0000000000000000 (NULL)               0x0
```

你注意到了什么吗？ 它与 GOT 的值相同。 这意味着 GOT 中的前三个 8 字节条目实际上是保留区域; 因此总是由全局指针指向。

当动态链接器启动时，它有责任填充这些值.ABI 表示第一个值将由动态链接器填充，为该模块提供唯一的 ID。 第二个值是动态链接器的全局指针值，第三个值是查找和修复符号的函数的地址。

```c
                /* Set up the loaded object described by L so its unrelocated PLT
       entries will jump to the on-demand fixup code in dl-runtime.c.  */

    static inline int __attribute__ ((unused, always_inline))
    elf_machine_runtime_setup (struct link_map *l, int lazy, int profile)
    {
      extern void _dl_runtime_resolve (void);
      extern void _dl_runtime_profile (void);

      if (lazy)
        {
          register Elf64_Addr gp __asm__ ("gp");
          Elf64_Addr *reserve, doit;

          /*
           * Careful with the typecast here or it will try to add l-l_addr
           * pointer elements
           */
          reserve = ((Elf64_Addr *)
                     (l->l_info[DT_IA_64 (PLT_RESERVE)]->d_un.d_ptr + l->l_addr));
          /* Identify this shared object.  */
          reserve[0] = (Elf64_Addr) l;

          /* This function will be called to perform the relocation.  */
          if (!profile)
            doit = (Elf64_Addr) ((struct fdesc *) &_dl_runtime_resolve)->ip;
          else
            {
              if (GLRO(dl_profile) != NULL
                  && _dl_name_match_p (GLRO(dl_profile), l))
                {
                  /* This is the object we are looking for.  Say that we really
                     want profiling and the timers are started.  */
                  GL(dl_profile_map) = l;
                }
              doit = (Elf64_Addr) ((struct fdesc *) &_dl_runtime_profile)->ip;
            }

          reserve[1] = doit;
          reserve[2] = gp;
        }

      return lazy;
}
```

我们可以通过查看为二进制文件执行此操作的函数来查看动态链接器如何设置它。保留变量是从二进制文件中的 `PLT_RESERVE` 部分指针设置的。唯一值（put into `reserve[0]`）是此对象的链接映射的地址。链接映射是 glibc 中共享对象的内部表示。然后我们将`_dl_runtime_resolve` 的地址放入第二个值（假设我们没有使用分析）。 `reserve[2]`最终设置为 gp，已经从 r2 中找到**asm**调用。

回顾 ABI，我们看到条目的重定位索引必须放在 r15 中，唯一标识符必须在 r16 中传递。

在我们跳回到 PLT 的开头之前，r15 先前已经设置在存根代码中。查看条目，并注意每个 PLT 条目如何以递增的值加载 r15？如果你看一下 printf 重定位数为零的重定位，那就不足为奇了。

r16 我们从动态链接器初始化的值加载，如前所述。一旦准备就绪，我们可以加载函数地址和全局指针并分支到函数中。

此时发生的是运行动态链接器函数`_dl_runtime_resolve`。它找到了搬迁;还记得重定位如何指定符号的名称？它使用此名称来查找正确的功能;这可能涉及从磁盘加载库（如果它尚未在内存中），或者共享代码。

重定位记录为动态链接器提供了“修复”所需的地址;还记得它是在 GOT 中并由最初的 PLT 存根加载吗？这意味着在第一次调用函数后，第二次加载函数时，它将获得函数的直接地址;使动态链接器短路。

# Summary

您已经看到了 PLT 背后的确切机制，因此也看到了动态链接器的内部工作原理。 要记住的重点是

- 程序中的库调用实际上在二进制文件的 PLT 中调用了代码存根。
- 该存根代码加载一个地址并跳转到它。
- 最初，该地址指向动态链接器中的一个函数，该函数能够在给定该函数的重定位条目中的信息的情况下查找“真实”函数。
- 动态链接器重写存根代码读取的地址，以便下次调用该函数时，它将直接转到正确的地址。
