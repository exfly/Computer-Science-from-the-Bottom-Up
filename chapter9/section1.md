# Code Sharing

我们知道，对于操作系统代码，它被认为是只读的，并且与数据分开。似乎合乎逻辑的是，如果程序无法修改代码并拥有大量公共代码，而不是为每个可执行文件复制它，那么它应该在许多可执行文件之间共享。

使用虚拟内存，可以轻松完成。加载库代码的存储器的物理页面可以由任意数量的地址空间中的任意数量的虚拟页面容易地引用。因此，虽然您在系统内存中只有一个库代码的物理副本，但每个进程都可以在其喜欢的任何虚拟地址访问该库代码。

因此，人们很快想出了一个共享库的概念，顾名思义，它由多个可执行文件共享。每个可执行文件都包含一个基本上说“我需要库 foo”的引用。当程序加载时，系统要么检查某个其他程序是否已经将库 foo 的代码加载到内存中，然后通过将页面映射到该物理内存的可执行文件来共享它，或以其他方式加载库进入可执行文件的内存。

此过程称为动态链接，因为它在程序在系统中执行时“动态”执行链接过程的一部分。

## Dynamic Library Details

库非常像一个永远不会开始的程序。 它们具有代码和数据部分（函数和变量），就像每个可执行文件一样; 但没有从哪里开始。 它们只是为开发人员提供了一个函数库来调用。

因此，ELF 可以表示动态库，就像它执行可执行文件一样。 存在一些基本差异，例如没有指向执行应该从哪里开始的指针，但是所有共享库都只是 ELF 对象，就像任何其他可执行文件一样。

ELF 头有两个互斥标志`ET_EXEC`和`ET_DYN`，用于将 ELF 文件标记为可执行文件或共享对象文件。

## Including libraries in an executable

### Compilation

编译使用动态库的程序时，目标文件将保留对库函数的引用，就像任何其他外部引用一样。

您需要包含库的头，以便编译器知道您调用的函数的特定类型。 请注意，编译器只需要知道与函数关联的类型（例如，它接受一个 int 并返回一个 char \*），以便它可以正确地为函数调用分配空间。

### Linking

即使动态链接器为共享库执行了大量工作，传统链接器仍然可以在创建可执行文件时发挥作用。

传统链接器需要在可执行文件中留下指针，以便动态链接器知道哪个库将在运行时满足依赖关系。

可执行文件的动态部分需要可执行文件所依赖的每个共享库的`NEEDED`条目。

同样，我们可以使用`readelf`程序检查这些字段。 下面我们来看一个非常标准的二进制文件`/bin/ls`

`$ readelf --dynamic /bin/ls`

```
Dynamic section at offset 0x20a98 contains 24 entries:
  Tag        Type                         Name/Value
 0x0000000000000001 (NEEDED)             Shared library: [libcap.so.2]
 0x0000000000000001 (NEEDED)             Shared library: [libc.so.6]
 0x000000000000000c (INIT)               0x4000
 0x000000000000000d (FINI)               0x16da4
 0x0000000000000019 (INIT_ARRAY)         0x21050
 0x000000000000001b (INIT_ARRAYSZ)       8 (bytes)
 0x000000000000001a (FINI_ARRAY)         0x21058
 0x000000000000001c (FINI_ARRAYSZ)       8 (bytes)
 0x000000006ffffef5 (GNU_HASH)           0x308
 0x0000000000000005 (STRTAB)             0xfa0
 0x0000000000000006 (SYMTAB)             0x3b8
 0x000000000000000a (STRSZ)              1445 (bytes)
 0x000000000000000b (SYMENT)             24 (bytes)
 0x0000000000000015 (DEBUG)              0x0
 0x0000000000000007 (RELA)               0x16b8
 0x0000000000000008 (RELASZ)             7440 (bytes)
 0x0000000000000009 (RELAENT)            24 (bytes)
 0x0000000000000018 (BIND_NOW)
 0x000000006ffffffb (FLAGS_1)            Flags: NOW PIE
 0x000000006ffffffe (VERNEED)            0x1648
 0x000000006fffffff (VERNEEDNUM)         1
 0x000000006ffffff0 (VERSYM)             0x1546
 0x000000006ffffff9 (RELACOUNT)          193
 0x0000000000000000 (NULL)               0x0
```

您可以看到它指定了三个库。 系统上大多数（如果不是全部）程序共享的最常见的库是 libc。 还有一些程序需要正确运行的其他库。

直接读取 ELF 文件有时很有用，但检查动态链接可执行文件的常用方法是通过 ldd。 ldd 为你“walks”了lib的依赖关系; 也就是说，如果某个库依赖于另一个库，它将向您显示。

`$ ldd /bin/ls`

```
linux-vdso.so.1 (0x00007ffd39b5e000)
libcap.so.2 => /usr/lib/libcap.so.2 (0x00007f2d32459000)
libc.so.6 => /usr/lib/libc.so.6 (0x00007f2d32296000)
/lib64/ld-linux-x86-64.so.2 => /usr/lib64/ld-linux-x86-64.so.2 (0x00007f2d3248e000)
```

`$ readelf --dynamic /usr/lib/libc.so.6`

```
Dynamic section at offset 0x1ba9e0 contains 27 entries:
  Tag        Type                         Name/Value
 0x0000000000000001 (NEEDED)             Shared library: [ld-linux-x86-64.so.2]
 0x000000000000000e (SONAME)             Library soname: [libc.so.6]
 0x000000000000000c (INIT)               0x26c60
 0x0000000000000019 (INIT_ARRAY)         0x1b9330
 0x000000000000001b (INIT_ARRAYSZ)       16 (bytes)
 0x0000000000000004 (HASH)               0x3b8
 0x000000006ffffef5 (GNU_HASH)           0x3888
 0x0000000000000005 (STRTAB)             0x15270
 0x0000000000000006 (SYMTAB)             0x7518
 0x000000000000000a (STRSZ)              24691 (bytes)
 0x000000000000000b (SYMENT)             24 (bytes)
 0x0000000000000003 (PLTGOT)             0x1bbbd0
 0x0000000000000002 (PLTRELSZ)           1128 (bytes)
 0x0000000000000014 (PLTREL)             RELA
 0x0000000000000017 (JMPREL)             0x245c8
 0x0000000000000007 (RELA)               0x1c9d8
 0x0000000000000008 (RELASZ)             31728 (bytes)
 0x0000000000000009 (RELAENT)            24 (bytes)
 0x000000006ffffffc (VERDEF)             0x1c558
 0x000000006ffffffd (VERDEFNUM)          31
 0x000000000000001e (FLAGS)              BIND_NOW STATIC_TLS
 0x000000006ffffffb (FLAGS_1)            Flags: NOW
 0x000000006ffffffe (VERNEED)            0x1c9a8
 0x000000006fffffff (VERNEEDNUM)         1
 0x000000006ffffff0 (VERSYM)             0x1b2e4
 0x000000006ffffff9 (RELACOUNT)          1232
 0x0000000000000000 (NULL)               0x0
```
