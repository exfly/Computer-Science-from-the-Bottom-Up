# A practical example

我们可以逐步完成构建简单应用程序所采取的步骤。

请注意，当您键入实际运行驱动程序的 gcc 时，该程序会隐藏您的大部分步骤。 在正常情况下，这正是您想要的，因为在真实系统上获得真实生活可执行文件的确切命令和选项可能非常复杂且特定于体系结构。

我们将使用以下两个示例显示编译过程。 两者都是 C 源文件，一个定义了初始程序入口点的 main（）函数，另一个声明了一个辅助类型函数。 还有一个全局变量，仅用于说明。

```c
#include <stdio.h>

/* We need a prototype so the compiler knows what types function() takes */
int function(char *input);

/* Since this is static, we can define it in both hello.c and function.c */
static int i = 100;

/* This is a global variable */
int global = 10;

int main(void)
{
    /* function() should return the value of global */
    int ret = function("Hello, World!");
    exit(ret);
}
```

```c
#include <stdio.h>

static int i = 100;

/* Declard as extern since defined in hello.c */
extern int global;

int function(char *input)
{
    printf("%s\n", input);
    return global;
}
```

## Compiling

所有编译器都可以选择只执行编译的第一步。 通常这类似于-S，输出通常会放入一个与输入文件同名但扩展名为.s 的文件中。

因此，我们可以使用 gcc -S 显示第一步

组件有点复杂到完全描述，但你应该能够看到我被定义为 data4（即 4 个字节或 32 位，int 的大小），其中函数被定义（函数:)和 a 打电话给 printf（）。

我们现在有两个汇编文件可以组装成机器代码！

## Assembly

装配是一个相当直接的过程。 汇编程序通常被称为并以与 gcc 类似的方式获取参数

`as -o hello.o hello.s`
`as -o func.o func.s`

组装完成后，我们有了目标代码，可以将它们链接到最终的可执行文件中。 您通常可以通过使用-c 调用编译器来手动使用汇编程序，它将直接将输入文件转换为目标代码，将其放在具有相同前缀但.o 作为扩展名的文件中。

我们无法直接检查目标代码，因为它是二进制格式（在未来几周我们将了解这种二进制格式）。 但是我们可以使用一些工具来检查目标文件，例如 readelf --symbols 会在目标文件中显示符号。

`readelf --symbols ./hello.o`

虽然输出非常复杂（再次！），你应该能够理解它的大部分内容。 例如

- 在 hello.o 的输出中，查看名称为 i 的符号。 请注意它是如何说它是 LOCAL？ 那是因为我们声明它是静态的，因此它被标记为该对象文件的本地。
- 在同一输出中，请注意全局变量被定义为 GLOBAL，这意味着它在此文件外部可见。 类似地，main（）函数是外部可见的。
- 请注意，函数符号（用于调用 function（））具有 UND 或 undefined。这意味着它已留给链接器查找函数的地址。
- 查看 function.c 文件中的符号以及它们如何适合输出。

## Linking

实际上调用名为 ld 的链接器在实际系统上是一个非常复杂的过程（您是否厌倦了听到这个？）。 这就是我们将链接过程留给 gcc 的原因。

但是当然我们可以通过-v（详细）标志监视 gcc 在幕后做什么。

您注意到的第一件事是调用名为 collect2 的程序。 这是一个简单的 ld 包装器，由 gcc 内部使用。

您接下来要注意的是以链接器指定的 crt 开头的对象文件。 这些函数由 gcc 和系统库提供，包含启动程序所需的代码。 实际上，main（）函数不是程序运行时调用的第一个函数，而是一个名为\_start 的函数，它位于 crt 目标文件中。 此函数执行一些通用设置，应用程序员无需担心这些设置。

路径层次结构非常复杂，但实质上我们可以看到最后一步是链接一些额外的目标文件，即

crt1.o：由系统库（libc）提供，这个目标文件包含\_start 函数，它实际上是程序中调用的第一个函数。

crti.o：由系统库提供

crtbegin.o

crtsaveres.o

crtend.o

crtn.o

我们将讨论如何使用这些程序稍后启动程序。

接下来，您可以看到我们在两个目标文件 hello.o 和 function.o 中进行链接。 之后，我们使用-l 标志指定一些额外的库。 这些库是特定于系统的，是每个程序所必需的。 主要的是-lc，它引入了 C 库，它具有所有常见功能，如 printf（）。

之后，我们再次链接一些更多的系统对象文件，这些文件在程序退出后进行一些清理。

虽然细节很复杂，但这个概念很简单。 所有目标文件将链接在一起成为一个可执行文件，随时可以运行！

## The Executable

我们将在短期内详细介绍可执行文件，但我们可以以与目标文件类似的方式进行一些检查，看看发生了什么。

有些事情需要注意

- 注意我以“简单”的方式构建了可执行文件！
- 看到有两个符号表; dynsym 和 symtab。 我们解释了 dynsym 符号如何很快起作用，但请注意其中一些符号的版本是@符号。
- 请注意额外目标文件中包含的许多符号。 他们中的许多人都以`__`开头，以避免与程序员可能选择的任何名称发生冲突。 仔细阅读并从目标文件中挑选出我们之前提到的符号，看看它们是否以任何方式发生了变化。
