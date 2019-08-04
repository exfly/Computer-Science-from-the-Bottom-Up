# Consequences of virtual addresses, pages and page tables

虚拟寻址，页面和页表是每个现代操作系统的基础。 它支持我们使用系统的大部分内容。

## Individual address spaces

通过为每个进程提供自己的页表，每个进程都可以假装它可以访问处理器可用的整个地址空间。两个进程可能使用相同的地址并不重要，因为每个进程的不同页表将它映射到不同的物理内存帧。每个现代操作系统都为每个进程提供了自己的地址空间。

随着时间的推移，物理内存变得支离破碎，这意味着物理内存中存在自由空间的“漏洞”。必须解决这些漏洞最多是烦人的，并且会成为程序员的严重限制。例如，如果你是 malloc 8 KiB 的内存;需要支持两个 4 KiB 帧，如果这些帧必须是连续的（即，物理上彼此相邻），那将是一个巨大的不确定。使用虚拟地址并不重要;就进程而言，它具有 8 KiB 的连续内存，即使这些页面由相距很远的帧支持。通过为每个进程分配虚拟地址空间，程序员可以将分段工作留给操作系统。

## Protection

我们之前提到 386 处理器的虚拟模式称为保护模式，这个名称源于虚拟内存可以为其上运行的进程提供的保护。

在没有虚拟内存的系统中，每个进程都可以完全访问所有系统内存。这意味着没有什么可以阻止一个进程覆盖另一个进程内存，导致它崩溃（或者更糟糕的是，返回错误的值，特别是如果该程序正在管理您的银行帐户！）

提供此级别的保护是因为操作系统现在是进程和内存访问之间的抽象层。如果进程提供的页面表未覆盖虚拟地址，那么操作系统就会知道该进程出错了并且可以通知它已经超出其边界的进程。

由于每个页面都有额外的属性，因此页面可以设置为只读，只写或具有任意数量的其他有趣属性。当进程尝试访问该页面时，操作系统可以检查它是否具有足够的权限，如果没有则停止（例如，写入只读页面）。

使用虚拟内存的系统本质上更稳定，因为假设完美的操作系统，一个进程只能崩溃自己而不是整个系统（当然，人类编写操作系统，我们不可避免地忽略了仍然会导致整个系统崩溃的错误）。

## Swap

我们现在还可以看到交换内存是如何实现的。 如果不是指向系统内存区域，则可以将页面指针更改为指向磁盘上的某个位置。

引用此页面时，操作系统需要将其从磁盘移回系统内存（请记住，程序代码只能从系统内存执行）。 如果系统内存已满，则需要将另一个页面踢出系统内存并放入交换磁盘，然后才能将所需页面放入内存。 如果另一个进程想要再次被踢回的页面，则重复该过程。

这可能是交换内存的主要问题。 从硬盘加载非常慢（与在内存中进行的操作相比）并且大多数人将熟悉坐在计算机前面而硬盘一直工作而系统仍然没有响应。

### mmap

一个不同但相关的过程是内存映射或 mmap（来自系统调用名称）。 如果不是页面表指向物理内存或交换页表指向文件，在磁盘上，我们说该文件是 mmaped。

通常，您需要在磁盘上打开文件以获取文件描述符，然后以顺序形式读取和写入。 当文件被映射时，它可以像系统 RAM 一样被访问

## Sharing memory

通常，每个进程都有自己的页表，因此它使用的任何地址都映射到物理内存中的唯一帧。但是，如果操作系统将两个页表条目指向同一帧，该怎么办？这意味着将共享此框架;并且一个进程所做的任何更改都将对另一个进行。

您现在可以看到如何实现线程。在名为“clone”的部分中，我们说 Linux clone（）函数可以根据需要与旧进程共享新进程的多少。如果进程调用 clone（）来创建新进程，但请求两个进程共享同一个页表，那么您实际上有一个线程，因为两个进程都看到相同的底层物理内存。

您现在还可以看到写入时的副本是如何完成的。如果将页面的权限设置为只读，则当进程尝试写入页面时，将通知操作系统。如果它知道该页面是写入时复制页面，那么它需要在系统内存中创建页面的新副本，并将页面表中的页面指向此新页面。然后，可以将其属性更新为具有写入权限，并且该进程具有其自己的页面唯一副本。

## Disk Cache

在现代系统中，通常的情况是，不是内存太少而且必须交换内存，因此可用的内存比系统当前使用的内存多。

内存层次结构告诉我们磁盘访问比内存访问慢得多，因此如果可能的话，将尽可能多的数据从磁盘移动到系统内存中是有意义的。

Linux 和许多其他系统在使用时会将磁盘上文件的数据复制到内存中。 即使程序最初只请求文件的一小部分，很可能在继续处理时它将要访问文件的其余部分。 当操作系统必须读取或写入文件时，它首先检查文件是否在其内存缓存中。

当系统中的内存压力增加时，这些页面应该是第一个被删除的页面。

## Page Cache

讨论内核时可能会听到的一个术语是页面缓存。

页面缓存是指内核保留的引用磁盘上文件的页面列表。 从上面看，交换页面，mmaped 页面和磁盘缓存页面都属于这一类。 内核保留了这个列表，因为它需要能够快速查找它们以响应读写请求