# The Toolchain

## Compiled v Interpreted Programs

### Compiled Programs

到目前为止，我们已经讨论了如何将程序加载到虚拟内存中，作为一个由操作系统跟踪的进程启动并通过系统调用进行交互。

可以直接加载到内存中的程序需要采用直接二进制格式。 将用 C 语言编写的源代码转换为准备执行的二进制文件的过程称为编译。 毫不奇怪，这个过程是由编译器完成的; 最广泛的例子是 gcc。

### Interpreted programs

编译程序对于现代软件开发具有一些缺点。每次开发人员进行更改时，都必须调用编译器来重新创建可执行文件。它是设计编译程序的逻辑扩展，可以读取另一个程序列表并逐行执行代码。

我们将这种类型的编译程序称为解释器，因为它解释输入文件的每一行并将其作为代码执行。这样，程序不需要编译，并且下次解释器运行代码时将看到任何更改。

为方便起见，解释程序通常比编译程序运行得慢。程序读取和解释代码的开销每次只对编译程序遇到一次，而解释程序每次运行时都会遇到它。

但是解释型语言有许多积极的方面。许多解释语言实际上在从底层硬件中抽象出来的虚拟机中运行。 Python 和 Perl 6 是实现解释代码运行的虚拟机的语言。

### Virtual Machines

编译的程序完全依赖于编译它的机器的硬件，因为它必须能够简单地复制到存储器并执行。 虚拟机是硬件到软件的抽象。

例如，Java 是一种混合语言，部分编译和部分解释。 Java 代码被编译到在 Java 虚拟机内部运行的程序中，或者通常称为 JVM。 这意味着编译的程序可以在任何为其编写 JVM 的硬件上运行; 所谓的写一个，在任何地方运行。
