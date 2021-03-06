# 组织操作系统

操作系统大致如下图所示
![The Operating System](http://www.bottomupcs.com/chapter03/figures/kernel.png)

## The Kernel

内核是操作系统。如图所示，内核直接和通过驱动程序与硬件通信。

正如内核将硬件抽象为用户程序一样，驱动程序将硬件抽象到内核。例如，有许多不同类型的图形卡，每个图形卡具有略微不同的特征。只要内核导出 API，有权访问硬件规范的人就可以编写驱动程序来实现该 API。这样内核可以访问许多不同类型的硬件。

内核通常被称为特权。您将了解到，硬件在运行多个任务和保持系统安全方面可以发挥重要作用，但这些规则不适用于内核。我们知道内核必须处理崩溃的程序（记住它是在同一系统上运行的多个程序之间的操作系统作业仲裁，并且不能保证它们会表现），但是如果操作系统的任何内部部分崩溃了机会是整个系统将变得无用。同样，用户进程可以利用安全问题将自己升级到内核的权限级别;此时，他们可以完全取消选中系统的任何部分。

### 宏内核 vs 微内核

围绕操作系统经常出现的一个争论是内核应该是微内核还是宏内核。

宏内核方法是最常见的方法，正如大多数常见的 Unix（例如 Linux）所采用的方法。在此模型中，核心特权内核很大，包含硬件驱动程序，文件系统访问控制，权限检查和网络文件系统（NFS）等服务。

由于内核总是具有特权，如果内核的任何部分崩溃，整个系统都有可能停止运行。如果一个驱动程序有错误，它可以覆盖系统中的任何内存而不会出现问题，最终导致系统崩溃。

微内核架构试图通过使内核的特权部分尽可能小来最小化这种可能性。这意味着大多数系统都作为非特权程序运行，从而限制了任何一个崩溃组件可能产生的影响。例如，硬件驱动程序可以在不同的进程中运行，因此如果误入歧途，它就不能覆盖任何内存，而是分配给它。

虽然这听起来像是最明显的想法，但问题又出现了两个主要问题

1. 性能下降。在许多不同组件之间进行交谈会降低性能

- 这对程序员来说稍微困难一些。

这两种批评都是因为要保持组件之间的分离，大多数微内核都是通过基于消息传递的系统实现的，通常称为进程间通信或 IPC。各个组件之间的通信是通过离散消息进行的，这些消息必须捆绑在一起，发送到另一个组件，非捆绑，操作，重新捆绑和发回，然后再次拆分以获得结果。

对于来自外部组件的相当简单的请求，这是很多步骤。显然，一个请求可能会使另一个组件对更多组件执行更多请求，并且问题可能会成倍增加。缓慢的消息传递实现主要是早期微内核系统性能不佳的原因，而传递消息的概念对于程序员来说是稍微难以编程的。单独运行组件的增强保护不足以克服早期微内核系统中的这些障碍，因此它们已经过时了。

在宏内核中，组件之间的调用是简单的函数调用，正如所有程序员都熟悉的那样。

关于哪个是最好的组织，没有明确的答案，它在学术界和非学术界都引发了许多争论。希望当您了解有关操作系统的更多信息时，您将能够自己决定！

### Modules

Linux 内核实现了一个模块系统，驱动程序可以根据需要“动态”加载到正在运行的内核中。 这很好，因为构成操作系统代码很大一部分的驱动程序不会加载到系统中不存在的设备。 想要使最通用内核成为可能的人（即在许多不同的硬件上运行，例如 RedHat 或 Debian）可以将大多数驱动程序包括为仅在其运行的系统具有可用硬件时才加载的模块。

但是，模块直接加载到特权内核中，并在与内核其余部分相同的权限级别运行，因此系统仍被视为宏内核。

## 虚拟化（Virtualisation）

与内核密切相关的是硬件虚拟化的概念。 现代计算机非常强大，并且通常将它们作为整个系统而不是将单个物理计算机分成单独的“虚拟”计算机是有用的。 这些虚拟机中的每一个都将所有意图和目的看作一个完全独立的机器，尽管它们在同一个地方都在同一个盒子中。

![The Operating System](http://www.bottomupcs.com/chapter03/figures/virtual.png)

这可以通过许多不同的方式组织。在最简单的情况下，小型虚拟机监视器可以直接在硬件上运行，并为运行在顶部的客户机操作系统提供接口。这个 VMM 通常被称为管理程序（来自“主管”一词）[10]。事实上，顶层的操作系统可能根本不知道虚拟机管理程序是否存在，因为虚拟机管理程序呈现的似乎是一个完整的系统。它拦截客户操作系统和硬件之间的操作，并且仅向每个操作系统提供系统资源的子集。

这通常用于大型机器（具有许多 CPU 和大量 RAM）以实现分区。这意味着可以将机器拆分为较小的虚拟机。通常，您可以根据需要为动态运行系统分配更多资源。许多大型 IBM 机器上的虚拟机管理程序实际上是相当复杂的事务，具有数百万行代码。它提供了大量的系统管理服务。

另一个选择是让操作系统知道底层管理程序，并通过它请求系统资源。由于其中途性质，这有时被称为半虚拟化。这与 Xen 系统早期版本的工作方式类似，是一种折衷的解决方案。它有望提供更好的性能，因为操作系统在需要时明确要求来自管理程序的系统资源，而不是虚拟机管理程序必须动态地解决问题。

最后，您可能遇到这样的情况：在现有操作系统之上运行的应用程序提供了可以运行普通操作系统的虚拟化系统（包括 CPU，内存，BIOS，磁盘等）。应用程序通过现有操作系统将请求转换为底层硬件。这类似于 VMWare 的工作方式。这种方法有很多开销，因为应用程序进程必须模拟整个系统并将所有内容转换为来自底层操作系统的请求。但是，这使您可以一起模拟完全不同的体系结构，因为您可以将指令从一种处理器类型动态转换为另一种处理器类型（因为 Rosetta 系统使用从 PowerPC 处理器转移到基于 Intel 的处理器的 Apple 软件）。

在使用任何这些虚拟化技术时，性能是主要问题，因为曾经直接在硬件上进行快速操作需要通过抽象层来实现。

英特尔已经讨论了即将推出最新处理器的虚拟化硬件支持。这些扩展通过为可能需要介入虚拟机监视器的操作引发特殊异常来工作。因此，处理器看起来与运行在其上的应用程序的非虚拟化处理器相同，但是当该应用程序请求可能在其他客户机操作系统之间共享的资源时，可以调用虚拟机监视器。

这提供了卓越的性能，因为虚拟机监视器不需要监视每个操作以查看它是否安全，但可以等到处理器通知发生了不安全的事情。

### 隐蔽频道

这是一个题外话，但与虚拟化机器有关的一个有趣的安全漏洞。如果系统的分区不是静态的，而是动态的，则存在潜在的安全问题。

在动态系统中，根据需要将资源分配给在顶部运行的操作系统。因此，如果一个人正在进行特别 CPU 密集型操作而另一个正在等待来自磁盘的数据，则将更多的 CPU 功率提供给第一个任务。在静态系统中，每个将获得 50％的未使用部分将浪费。

动态分配实际上打开了两个操作系统之间的通信通道。可以指示两个状态的任何地方都足以以二进制形式进行通信。想象一下，这两个系统都是非常安全的，并且任何信息都不应该在一个和另一个之间传递。两个有访问权限的人可以勾结，通过编写两个试图同时占用大量资源的程序来在它们之间传递信息。

当一个人占用大量内存时，另一个人可用的内存较少。如果两者都跟踪最大分配，则可以传输一些信息。如果他们可以分配这么大的内存，他们会制定协议来检查每一秒。如果目标可以，即被认为是二进制 0，并且如果它不能（另一台机器具有所有内存），则被认为是二进制 1.每秒一位的数据速率并不令人惊讶，但信息正在流动。

这被称为隐蔽通道，虽然不可否认，但已经有来自这种机制的安全漏洞的例子。它只是表明系统程序员的生活从未如此简单！

## Userspace

我们称用户用户空间运行程序的理论位置。 每个程序在用户空间中运行，通过系统调用与内核通信（下面讨论）。
