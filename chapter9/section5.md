# Working with libraries and the linker

动态链接器的存在提供了我们可以利用的一些优点以及需要解决以获得功能系统的一些额外问题。

## Library versions

一个潜在的问题是不同版本的库。只有静态库，问题的可能性要小得多，因为所有库代码都直接构建在应用程序的二进制文件中。如果要使用新版本的库，则需要将其重新编译为新的二进制文件，替换旧的二进制文件。

对于常见的库来说，这显然是不切实际的，当然最常见的是 libc，它包含在大多数应用程序中。如果它仅作为静态库提供，则任何更改都需要重建系统中的每个应用程序。

但是，动态库工作方式的变化可能会导致多个问题。在最好的情况下，修改是完全兼容的，并且没有任何外部可见的改变。另一方面，这些更改可能会导致应用程序崩溃;例如，如果用于获取 int 的函数更改为采用 int \*。更糟糕的是，新的库版本可能已经改变了语义，突然开始静默地返回不同的，可能是错误的值。这可能是一个非常讨厌的错误，试图追踪;当应用程序崩溃时，您可以使用调试器来隔离错误发生的位置，而数据损坏或修改可能只会出现在应用程序看似无关的部分。

动态链接器需要一种方法来确定系统中库的版本，以便可以识别更新的版本。现代动态链接器可以使用许多方案来查找正确版本的库。

### sonames

使用 sonames，我们可以向库中添加一些额外的信息，以帮助识别版本。

正如我们之前看到的，应用程序在二进制文件的动态部分中的 DT_NEEDED 字段中列出了它所需的库。实际的库保存在光盘上的文件中，通常在`/lib` 中用于核心系统库，或者`/usr/lib` 用于可选库。

要允许磁盘上存在多个版本的库，它们显然需要不同的文件名。 soname 方案使用名称和文件系统链接的组合来构建库的层次结构。

这是通过引入主要和次要库修订的概念来完成的。次要修订版是完全向后兼容的库的先前版本;这通常只包含错误修复。因此，重大修订是任何不兼容的修订;例如将输入更改为函数或函数的行为方式。

由于每个库修订版本（主要版本或次要版本）都需要保存在磁盘上的单独文件中，因此这构成了库层次结构的基础。库名称通常是 libNAME.so.MAJOR.MINOR [29]。但是，如果每个应用程序都直接链接到此文件，我们将遇到与静态库相同的问题;每次发生微小变化时，我们都需要重建应用程序以指向新库。

我们真正想要提到的是 lib 的主要数量。如果这发生了变化，我们需要重新编译我们的应用程序，因为我们需要确保我们的程序仍然与新库兼容。

因此，soname 是 libNAME.so.MAJOR。 soname 应该在共享库的动态部分的 DT_SONAME 字段中设置;库作者可以在构建库时指定此版本。

因此，光盘上的每个次要版本库文件都可以在其 DT_SONAME 字段中指定相同的主要版本号，从而允许动态链接器知道此特定库文件实现库 API 和 ABI 的特定主要版本。

为了跟踪这一点，通常运行名为 ldconfig 的应用程序，以便为主要版本创建为系统上最新次要版本命名的符号链接。 ldconfig 通过运行实现特定主要修订版号的所有库来工作，然后选择具有最高次要修订版的库。然后它创建一个从 libNAME.so.MAJOR 到光盘上实际库文件的符号链接，即 libNAME.so.MAJOR.MINOR。

XXX：谈论 libtool 版本

层次结构的最后一部分是库的编译名称。编译程序时，要链接库，请使用-lNAME 标志，该标志将在库搜索路径中搜索 libNAME.so 文件。但是请注意，我们没有指定任何版本号;我们只想链接系统上的最新库。库的安装过程取决于在编译 libNAME.so 名称和系统上的最新库代码之间创建符号链接。通常，这由包管理系统（dpkg 或 rpm）处理。这不是一个自动化过程，因为系统上的最新库可能不是您希望始终编译的库;例如，如果最新安装的库是不适合一般用途的开发版本。

![sonames](http://www.bottomupcs.com/chapter08/figures/libs.png)

### How the dynamic linker looks up libraries

应用程序启动时，动态链接器会查看 DT_NEEDED 字段以查找所需的库。该字段包含库的 soname，因此下一步是动态链接器遍历其搜索路径中的所有库以查找它。

该过程在概念上涉及两个步骤。首先，动态链接器需要搜索所有库以查找实现给定 soname 的库。其次，需要比较次要修订版的文件名以找到最新版本，然后准备加载。

我们之前提到过，ldconfig 在库 soname 和最新的次要修订版之间设置了符号链接。因此，动态链接器应该只需要跟随该链接以找到要加载的正确文件，而不是必须打开所有可能的库并决定每次需要应用程序时使用哪个库。

由于文件系统访问速度很慢，因此 ldconfig 还会创建系统中安装的库的缓存。此缓存只是动态链接器可用的库的名称列表以及指向磁盘上主要版本链接的指针，从而使动态链接器不必读取整个文件目录以找到正确的链接。您可以使用`/sbin/ldconfig -p`进行分析;它实际上存在于文件`/etc/ldconfig.so.cache`中。如果在缓存中找不到库，则动态链接器将回退到文件系统的较慢选项，因此在安装新库时重新运行 ldconfig 非常重要。

## Finding symbols

我们已经讨论了动态链接器如何获取库函数的地址并将其放入 PLT 以供程序使用。 但到目前为止，我们还没有讨论动态链接器如何找到函数的地址。 整个过程称为绑定，因为符号名称绑定到它表示的地址。

动态链接器有一些信息; 首先是它正在搜索的符号，其次是该符号可能所在的库列表，由二进制文件中的 DT_NEEDED 字段定义。

每个共享对象库都有一个标记为 SHT_DYNSYM 且名为.dynsym 的部分，它是动态链接所需的最小符号集 - 即库中可由外部程序调用的任何符号。

### Dynamic Symbol Table

事实上，有三个部分都在描述动态符号中起作用。 首先，让我们看一下 ELF 规范中符号的定义

```c
typedef struct {
    Elf32_Word    st_name;
    Elf32_Addr    st_value;
    Elf32_Word    st_size;
    unsigned char st_info;
    unsigned char st_other;
    Elf32_Half    st_shndx;
} Elf32_Sym;
```

| Field    | Value                                                                                                                 |
| -------- | --------------------------------------------------------------------------------------------------------------------- |
| st_name  | An index to the string table                                                                                          |
| st_value | Value - in a relocatable shared object this holds the offset from the section of index given in st_shndx              |
| st_size  | Any associated size of the symbol                                                                                     |
| st_info  | Information on the binding of the symbol (described below) and what type of symbol this is (a function, object, etc). |
| st_other | Not currently used                                                                                                    |
| st_shndx | Index of the section this symbol resides in (see st_value                                                             |

如您所见，符号名称的实际字符串保存在单独的部分中（.dynstr; .dynsym 部分中的条目仅包含字符串部分的索引。这为动态链接器创建了一定程度的开销; 动态链接器必须读取.dynsym 部分中的所有符号条目，然后按照索引指针查找符号名称以进行比较。

为了加快此过程，引入了第三个名为.hash 的部分，其中包含符号名称到符号表条目的哈希表。 在构建库时预先计算此哈希表，并允许动态链接器更快地找到符号条目，通常只有一次或两次查找。

### Symbol Binding

虽然我们通常说找到符号地址的过程是绑定该符号的过程，但符号绑定具有单独的含义。

符号的绑定决定了它在动态链接过程中的外部可见性。 在定义的目标文件外部看不到本地符号。全局符号对其他目标文件可见，并且可以满足其他对象中未定义的引用。

弱引用是一种特殊类型的低优先级全局引用。 这意味着它被设计为被覆盖，我们很快就会看到。

下面我们有一个示例 C 程序，我们分析它来检查符号绑定。

```
    $ cat test.c
    static int static_variable;

    extern int extern_variable;

    int external_function(void);

    int function(void)
    {
            return external_function();
    }

    static int static_function(void)
    {
            return 10;
    }

    #pragma weak weak_function
    int weak_function(void)
    {
            return 10;
    }

    $ gcc -c test.c
    $ objdump --syms test.o

    test.o:     file format elf32-powerpc

    SYMBOL TABLE:
    00000000 l    df *ABS*  00000000 test.c
    00000000 l    d  .text  00000000 .text
    00000000 l    d  .data  00000000 .data
    00000000 l    d  .bss   00000000 .bss
    00000038 l     F .text  00000024 static_function
    00000000 l    d  .sbss  00000000 .sbss
    00000000 l     O .sbss  00000004 static_variable
    00000000 l    d  .note.GNU-stack        00000000 .note.GNU-stack
    00000000 l    d  .comment       00000000 .comment
    00000000 g     F .text  00000038 function
    00000000         *UND*  00000000 external_function
    0000005c  w    F .text  00000024 weak_function

    $ nm test.o
             U external_function
    00000000 T function
    00000038 t static_function
    00000000 s static_variable
    0000005c W weak_function
```

注意使用#pragma 来定义弱符号。 编译指示是一种将额外信息传递给编译器的方法; 它的使用并不常见，但偶尔需要让编译器完成普通的操作

我们用两种不同的工具检查符号; 在这两种情况下，绑定显示在第二列; 代码应该非常简单（在工具手册页中有记录）。

#### Overriding symbols

程序员能够覆盖库中的符号通常非常有用; 即用不同的定义颠覆普通符号。

我们提到搜索库的顺序是由库中 DT_NEEDED 字段的顺序给出的。 但是，可以插入库作为要搜索的最后一个库; 这意味着它们中的任何符号都将作为最终参考。

这是通过一个名为 LD_PRELOAD 的环境变量完成的，该变量指定链接器最后应加载的库。

```
    $ cat override.c
    #define _GNU_SOURCE 1
    #include <stdio.h>
    #include <stdlib.h>
    #include <unistd.h>
    #include <sys/types.h>
    #include <dlfcn.h>

    pid_t getpid(void)
    {
            pid_t (*orig_getpid)(void) = dlsym(RTLD_NEXT, "getpid");
            printf("Calling GETPID\n");

            return orig_getpid();
    }

    $ cat test.c
    #include <stdio.h>
    #include <stdlib.h>
    #include <unistd.h>

    int main(void)
    {
            printf("%d\n", getpid());
    }

    $ gcc -shared -fPIC -o liboverride.so override.c -ldl
    $ gcc -o test test.c
    $ LD_PRELOAD=./liboverride.so ./test
    Calling GETPID
    15187
```

在上面的例子中，我们重写 getpid 函数，在调用它时打印出一个小语句。 我们使用 libc 提供的 dlysm 函数和一个参数告诉它继续并找到下一个名为 getpid 的符号。

#### 随着时间的推移弱符号

弱符号的概念是符号被标记为较低优先级并且可以被另一个符号覆盖。只有在没有找到其他实现时，弱符号才是它所使用的符号。

动态加载器的逻辑扩展是应该加载所有库，并且对于任何其他库中的普通符号，应忽略这些库中的任何弱符号。这确实是 glibc 最初在 Linux 中实现的弱符号处理方式。

但是，这对于当时 Unix 标准的字母（SysVr4）实际上是不正确的。该标准实际上规定弱符号应该只由静态链接器处理;它们应与动态链接器保持无关（请参阅下面的绑定顺序部分）。

当时，使动态链接器覆盖与 SGI 的 IRIX 平台匹配的弱符号的 Linux 实现，但与 Solaris 和 AIX 之类的其他不同。当开发人员意识到这种行为违反了标准时，它被颠倒了，旧的行为降级为需要一个特殊的环境标志（LD_DYNAMIC_WEAK）。

#### 指定绑定顺序

我们已经看到了如何通过预加载另一个定义了相同符号的共享库来覆盖另一个库中的函数。作为最后一个解析的符号是动态加载程序加载库的顺序中的最后一个符号。

库按照在二进制文件的 DT_NEEDED 标志中指定的顺序加载。这又是根据构建对象时在命令行上传入库的顺序决定的。当要定位符号时，动态链接器从最后加载的库开始，然后向后工作直到找到符号。

但是，某些共享库需要一种方法来覆盖此行为。他们需要对动态链接器说“在我内部查找这些符号，而不是从最后加载的库中向后工作”。库可以在其动态节头中设置 DT_SYMBOLIC 标志以获得此行为（这通常通过在构建共享库时在静态链接器命令行上传递-Bsymbolic 标志来设置）。

这个标志正在做的是控制符号可见性。库中的符号无法被覆盖，因此可以将其视为对正在加载的库的私有。

但是，这会丢失很多粒度，因为库要么标记此行为，要么不标记。一个更好的系统将允许我们使一些符号私有和一些符号公开。

#### 符号版本控制

更好的系统来自符号版本控制。使用符号版本控制，我们为静态链接器指定一些额外的输入，以便为它提供有关共享库中符号的更多信息。

```
    $ cat Makefile
    all: test testsym

    clean:
            rm -f *.so test testsym

    liboverride.so : override.c
            $(CC) -shared -fPIC -o liboverride.so override.c

    libtest.so : libtest.c
            $(CC) -shared -fPIC -o libtest.so libtest.c

    libtestsym.so : libtest.c
            $(CC) -shared -fPIC -Wl,-Bsymbolic -o libtestsym.so libtest.c

    test : test.c libtest.so liboverride.so
            $(CC) -L. -ltest -o test test.c

    testsym : test.c libtestsym.so liboverride.so
            $(CC) -L. -ltestsym -o testsym test.c

    $ cat libtest.c
    #include <stdio.h>

    int foo(void) {
            printf("libtest foo called\n");
            return 1;
    }

    int test_foo(void)
    {
            return foo();
    }

    $ cat override.c
    #include <stdio.h>

    int foo(void)
    {
            printf("override foo called\n");
            return 0;
    }

    $ cat test.c
    #include <stdio.h>

    int main(void)
    {
            printf("%d\n", test_foo());
    }

    $ cat Versions
    {global: test_foo;  local: *; };

    $ gcc -shared -fPIC -Wl,-version-script=Versions -o libtestver.so libtest.c

    $ gcc -L. -ltestver -o testver test.c

    $ LD_LIBRARY_PATH=. LD_PRELOAD=./liboverride.so ./testver
    libtest foo called

    100000574 l     F .text	00000054              foo
    000005c8 g     F .text	00000038              test_foo
```

在上面最简单的情况下，我们只是说明符号是全局的还是本地的。因此，在上面的情况下，foo 函数很可能是 test_foo 的支持函数;虽然我们很高兴要覆盖 test_foo 函数的整体功能，如果我们确实使用共享库版本，它需要具有未更改的访问权限，任何人都应该修改支持函数。

这使我们能够更好地组织命名空间。许多库可能想要实现一些可以命名为像读或写这样的常用函数的东西;但是，如果他们都这样做，那么给予该程序的实际版本可能是完全错误的。通过将符号指定为本地符号，开发人员可以确保没有任何内容与该内部名称冲突，相反，他选择的名称不会影响任何其他程序。

该方案的扩展是符号版本控制。通过此，您可以在同一个库中指定同一符号的多个版本。静态链接器在符号名称（类似于@VER）之后附加一些版本信息，描述符号的给定版本。

如果开发人员实现了具有相同名称但可能是二进制或编程不同的实现的函数，则可以增加版本号。当针对共享库构建新应用程序时，他们将获取最新版本的符号。但是，针对同一库的早期版本构建的应用程序将请求旧版本（例如，在它们请求的符号名称中将包含较旧的@VER 字符串），从而获得原始实现。