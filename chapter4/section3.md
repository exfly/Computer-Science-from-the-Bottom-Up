# 系统调用

## Overview

系统调用是用户空间程序与内核交互的方式。 它们如何工作的一般原则如下所述。

### System call numbers

每个系统调用都有一个系统调用号，用户空间和内核都知道。 例如，两者都知道系统调用号 10 是 open（），系统调用号 11 是 read（）等。

应用程序二进制接口（ABI）非常类似于 API，而不是软件用于硬件。 API 将定义应该将系统调用号放入哪个寄存器，以便内核在被要求进行系统调用时可以找到它。

### Arguments

没有参数，系统调用是没有用的; 例如 open（）需要准确地告诉内核要打开哪个文件。 ABI 将再次定义应该为系统调用放入哪些寄存器参数。

### 陷阱(The trap)

要实际执行系统调用，需要有一些方法与我们希望进行系统调用的内核进行通信。所有体系结构都定义了一条指令，通常称为 break 或类似的指令，它向我们希望进行系统调用的硬件发出信号。

具体来说，该指令将告诉硬件修改指令指针以指向内核系统调用处理程序（当操作系统设置其自身时，它告诉硬件其系统调用处理程序所在的位置）。因此，一旦用户空间调用 break 指令，它就会失去对程序的控制并将其传递给内核。

其余的操作相当直接。内核在预定义的寄存器中查找系统调用号，并在表中查找它以查看它应调用的函数。调用此函数，执行它需要做的操作，并将其返回值放入 ABI 定义的另一个寄存器作为返回寄存器。

最后一步是内核将跳转指令发送回用户空间程序，因此它可以从它离开的地方继续。 userpsace 程序从返回寄存器中获取所需的数据，并继续愉快地继续前进！

虽然这个过程的细节可能会变得非常繁琐，但基本上它们都是系统调用的。

### libc

虽然您可以为每个系统调用手动完成上述所有操作，但系统库通常会为您完成大部分工作。 在类似系统的 UNIX 上处理系统调用的标准库是 libc

# 分析系统调用

由于系统库通常会处理系统调用，我们需要进行一些低级别的黑客攻击，以准确说明系统调用的工作原理。

我们将说明最简单的系统调用 getpid（）是如何工作的。 此调用不带任何参数，并返回当前正在运行的程序（或进程;我们将在后几周查看该进程）的 ID。

```c
#include <stdio.h>

/* for syscall() */
#include <sys/syscall.h>
#include <unistd.h>

/* system call numbers */
#include <asm/unistd.h>

void function(void)
{
    int pid;
    pid = __syscall(__NR_getpid);
}
```

我们首先编写一个小型 C 程序，我们可以开始说明系统调用背后的机制。首先要注意的是系统库提供了一个 syscall 参数，用于直接进行系统调用。这为程序员提供了一种简单的方法，可以直接进行系统调用，而无需知道在其硬件上进行调用的确切汇编语言例程。那么我们为什么要使用 getpid（）呢？首先，在代码中使用符号函数名称要清楚得多。但是，更重要的是，getpid（）可能在不同的系统上以非常不同的方式工作。例如，在 Linux 上，可以缓存 getpid（）调用，因此如果它运行两次，系统库将不会因为必须再次进行整个系统调用来查找相同的信息而受到惩罚。

按照惯例，在 Linux 下，系统调用号在内核源的`asm/unistd.h`文件中定义。在 asm 子目录中，这对于运行 Linux 的每个体系结构都是不同的。按照惯例，系统调用号码被赋予一个由\_*NR*组成的#define 名称。因此，您可以看到我们的代码将进行 getpid 系统调用，将值存储在 pid 中。

我们将了解几个体系结构如何实现此代码。我们将看看真实的代码，所以事情会变得非常复杂。但坚持下去 - 这正是你的系统的运作方式！

## PowerPC

PowerPC 是旧版 Apple 计算机中常见的 RISC 架构，也是最新版 Xbox 等设备的核心。

```c

    /* On powerpc a system call basically clobbers the same registers like a
     * function call, with the exception of LR (which is needed for the
     * "sc; bnslr" sequence) and CR (where only CR0.SO is clobbered to signal
     * an error return status).
     */

    #define __syscall_nr(nr, type, name, args...)				\
    	unsigned long __sc_ret, __sc_err;				\
    	{								\
    		register unsigned long __sc_0  __asm__ ("r0");		\
    		register unsigned long __sc_3  __asm__ ("r3");		\
    		register unsigned long __sc_4  __asm__ ("r4");		\
    		register unsigned long __sc_5  __asm__ ("r5");		\
    		register unsigned long __sc_6  __asm__ ("r6");		\
    		register unsigned long __sc_7  __asm__ ("r7");		\
    									\
    		__sc_loadargs_##nr(name, args);				\
    		__asm__ __volatile__					\
    			("sc           \n\t"				\
    			 "mfcr %0      "				\
    			: "=&r" (__sc_0),				\
    			  "=&r" (__sc_3),  "=&r" (__sc_4),		\
    			  "=&r" (__sc_5),  "=&r" (__sc_6),		\
    			  "=&r" (__sc_7)				\
    			: __sc_asm_input_##nr				\
    			: "cr0", "ctr", "memory",			\
    			  "r8", "r9", "r10","r11", "r12");		\
    		__sc_ret = __sc_3;					\
    		__sc_err = __sc_0;					\
    	}								\
    	if (__sc_err & 0x10000000)					\
    	{								\
    		errno = __sc_ret;					\
    		__sc_ret = -1;						\
    	}								\
    	return (type) __sc_ret

    #define __sc_loadargs_0(name, dummy...)					\
    	__sc_0 = __NR_##name
    #define __sc_loadargs_1(name, arg1)					\
    	__sc_loadargs_0(name);						\
    	__sc_3 = (unsigned long) (arg1)
    #define __sc_loadargs_2(name, arg1, arg2)				\
    	__sc_loadargs_1(name, arg1);					\
    	__sc_4 = (unsigned long) (arg2)
    #define __sc_loadargs_3(name, arg1, arg2, arg3)				\
    	__sc_loadargs_2(name, arg1, arg2);				\
    	__sc_5 = (unsigned long) (arg3)
    #define __sc_loadargs_4(name, arg1, arg2, arg3, arg4)			\
    	__sc_loadargs_3(name, arg1, arg2, arg3);			\
    	__sc_6 = (unsigned long) (arg4)
    #define __sc_loadargs_5(name, arg1, arg2, arg3, arg4, arg5)		\
    	__sc_loadargs_4(name, arg1, arg2, arg3, arg4);			\
    	__sc_7 = (unsigned long) (arg5)

    #define __sc_asm_input_0 "0" (__sc_0)
    #define __sc_asm_input_1 __sc_asm_input_0, "1" (__sc_3)
    #define __sc_asm_input_2 __sc_asm_input_1, "2" (__sc_4)
    #define __sc_asm_input_3 __sc_asm_input_2, "3" (__sc_5)
    #define __sc_asm_input_4 __sc_asm_input_3, "4" (__sc_6)
    #define __sc_asm_input_5 __sc_asm_input_4, "5" (__sc_7)

    #define _syscall0(type,name)						\
    type name(void)								\
    {									\
    	__syscall_nr(0, type, name);					\
    }

    #define _syscall1(type,name,type1,arg1)					\
    type name(type1 arg1)							\
    {									\
    	__syscall_nr(1, type, name, arg1);				\
    }

    #define _syscall2(type,name,type1,arg1,type2,arg2)			\
    type name(type1 arg1, type2 arg2)					\
    {									\
    	__syscall_nr(2, type, name, arg1, arg2);			\
    }

    #define _syscall3(type,name,type1,arg1,type2,arg2,type3,arg3)		\
    type name(type1 arg1, type2 arg2, type3 arg3)				\
    {									\
    	__syscall_nr(3, type, name, arg1, arg2, arg3);			\
    }

    #define _syscall4(type,name,type1,arg1,type2,arg2,type3,arg3,type4,arg4) \
    type name(type1 arg1, type2 arg2, type3 arg3, type4 arg4)		\
    {									\
    	__syscall_nr(4, type, name, arg1, arg2, arg3, arg4);		\
    }

    #define _syscall5(type,name,type1,arg1,type2,arg2,type3,arg3,type4,arg4,type5,arg5) \
    type name(type1 arg1, type2 arg2, type3 arg3, type4 arg4, type5 arg5)	\
    {									\
    	__syscall_nr(5, type, name, arg1, arg2, arg3, arg4, arg5);	\
    }
```

内核头文件 `asm/unistd.h` 中的这段代码片段展示了我们如何在 PowerPC 上实现系统调用。它看起来很复杂，但可以一步一步地分解。

首先，跳转到定义\_syscallN 宏的示例的末尾。您可以看到有许多宏，每个宏逐渐采用另一个参数。我们将专注于最简单的版本`_syscall0` 开始。它只需要两个参数，系统调用的返回类型（例如 C int 或 char 等）和系统调用的名称。对于 getpid，这将作为`_syscall0（int，getpid）`完成。

容易到目前为止！我们现在必须开始拆分`__syscall_nr` 宏。这与我们之前的情况没有什么不同，我们将参数的数量作为第一个参数，类型，名称，然后是实际的参数。

第一步是为寄存器声明一些名称。这基本上做的是说`__sc_0` 指的是 r0（即寄存器 0）。编译器通常会使用它想要的寄存器，因此我们给它约束是很重要的，这样它就不会决定以某种特殊的方式使用我们需要的寄存器。

然后我们用有趣的##参数调用 `sc_loadargs`。这只是一个粘贴命令，它被 nr 变量取代。因此，对于我们的示例，它扩展为`__sc_loadargs_0(name, args)`;`__sc_loadargs` 我们可以在下面看到将`__sc_0` 设置为系统调用号;请注意粘贴运算符，使用我们所讨论的`__NR_`前缀，以及引用特定寄存器的变量名称。

所以，所有这些棘手的代码实际上都是将系统调用号放在寄存器 0 中！在代码通过之后，我们可以看到其他宏将系统调用参数放入 r3 到 r7（系统调用最多只能有 5 个参数）。

现在我们准备好解决`__asm__`部分。我们这里所谓的内联汇编是因为汇编代码与源代码混合在一起。这里的确切语法有点复杂，但我们可以指出重要的部分。

暂时忽略`__volatile__`位;它告诉编译器这个代码是不可预测的，所以它不应该尝试并且聪明起来。我们将再次从最后开始并向后工作。冒号之后的所有内容都是向编译器传达有关内联汇编对 CPU 寄存器执行的操作的一种方式。编译器需要知道，以便它不会尝试以可能导致崩溃的方式使用任何这些寄存器。

但有趣的是第一个参数中的两个汇编语句。完成所有工作的是 sc 调用。这就是您进行系统调用所需的全部工作！

那么这次通话会发生什么？好吧，处理器被中断，知道在系统启动时将控制转移到特定的代码设置来处理中断。中断很多;系统调用只是一个。然后，该代码将在寄存器 0 中查找系统调用号;然后它查找一个表并找到正确的函数来跳转到处理该系统调用。该函数在寄存器 3-7 中接收其参数。

那么，一旦系统调用处理程序运行并完成，会发生什么？控制返回 sc 之后的下一条指令，在本例中为内存栅栏指令。这基本上是说“确保一切都致力于记忆”;还记得我们如何谈论超标量体系结构中的管道？这条指令确保我们认为已经写入内存的所有内容实际上都是，并且没有通过某个地方的管道。

好吧，我们差不多完成了！唯一剩下的就是从系统调用中返回值。我们看到`__sc_ret` 是从 r3 设置的，\*\* sc_err 是从 r0 设置的。这是有趣的;这两个价值观都是关于什么的？

一个是返回值，一个是错误值。为什么我们需要两个变量？系统调用可能会失败，就像任何其他功能一样。问题是系统调用可以返回任何可能的值;我们不能说“负值表示失败”，因为对于某些特定的系统调用，负值可能是完全可接受的。

所以我们的系统调用函数在返回之前确保其结果在寄存器 r3 中，并且任何错误代码都在寄存器 r0 中。我们检查错误代码以查看是否设置了最高位;这表示负数。如果是这样，我们将全局 errno 值设置为它（这是获取有关调用失败的错误信息的标准变量）并将返回值设置为-1。当然，如果收到有效的结果，我们会直接退回。

所以我们的调用函数应该检查返回值是不是-1;如果是，它可以检查 errno 以找到呼叫失败的确切原因。

这就是 PowerPC 上的整个系统调用！

### x86 system calls

```c
/* user-visible error numbers are in the range -1 - -124: see <asm-i386/errno.h> */

    #define __syscall_return(type, res)				\
    do {								\
            if ((unsigned long)(res) >= (unsigned long)(-125)) {	\
                    errno = -(res);					\
                    res = -1;					\
            }							\
            return (type) (res);					\
    } while (0)

    /* XXX - _foo needs to be __foo, while __NR_bar could be _NR_bar. */
    #define _syscall0(type,name)			\
    type name(void)					\
    {						\
    long __res;					\
    __asm__ volatile ("int $0x80"			\
            : "=a" (__res)				\
            : "0" (__NR_##name));			\
    __syscall_return(type,__res);
    }

    #define _syscall1(type,name,type1,arg1)			\
    type name(type1 arg1)					\
    {							\
    long __res;						\
    __asm__ volatile ("int $0x80"				\
            : "=a" (__res)					\
            : "0" (__NR_##name),"b" ((long)(arg1)));	\
    __syscall_return(type,__res);
    }

    #define _syscall2(type,name,type1,arg1,type2,arg2)			\
    type name(type1 arg1,type2 arg2)					\
    {									\
    long __res;								\
    __asm__ volatile ("int $0x80"						\
            : "=a" (__res)							\
            : "0" (__NR_##name),"b" ((long)(arg1)),"c" ((long)(arg2)));	\
    __syscall_return(type,__res);
    }

    #define _syscall3(type,name,type1,arg1,type2,arg2,type3,arg3)		\
    type name(type1 arg1,type2 arg2,type3 arg3)				\
    {									\
    long __res;								\
    __asm__ volatile ("int $0x80"						\
            : "=a" (__res)							\
            : "0" (__NR_##name),"b" ((long)(arg1)),"c" ((long)(arg2)),	\
                      "d" ((long)(arg3)));					\
    __syscall_return(type,__res);						\
    }

    #define _syscall4(type,name,type1,arg1,type2,arg2,type3,arg3,type4,arg4)	\
    type name (type1 arg1, type2 arg2, type3 arg3, type4 arg4)			\
    {										\
    long __res;									\
    __asm__ volatile ("int $0x80"							\
            : "=a" (__res)								\
            : "0" (__NR_##name),"b" ((long)(arg1)),"c" ((long)(arg2)),		\
              "d" ((long)(arg3)),"S" ((long)(arg4)));				\
    __syscall_return(type,__res);							\
    }

    #define _syscall5(type,name,type1,arg1,type2,arg2,type3,arg3,type4,arg4,	\
              type5,arg5)								\
    type name (type1 arg1,type2 arg2,type3 arg3,type4 arg4,type5 arg5)		\
    {										\
    long __res;									\
    __asm__ volatile ("int $0x80"							\
            : "=a" (__res)								\
            : "0" (__NR_##name),"b" ((long)(arg1)),"c" ((long)(arg2)),		\
              "d" ((long)(arg3)),"S" ((long)(arg4)),"D" ((long)(arg5)));		\
    __syscall_return(type,__res);							\
    }

    #define _syscall6(type,name,type1,arg1,type2,arg2,type3,arg3,type4,arg4,			\
              type5,arg5,type6,arg6)								\
    type name (type1 arg1,type2 arg2,type3 arg3,type4 arg4,type5 arg5,type6 arg6)			\
    {												\
    long __res;											\
    __asm__ volatile ("push %%ebp ; movl %%eax,%%ebp ; movl %1,%%eax ; int $0x80 ; pop %%ebp"	\
            : "=a" (__res)										\
            : "i" (__NR_##name),"b" ((long)(arg1)),"c" ((long)(arg2)),				\
              "d" ((long)(arg3)),"S" ((long)(arg4)),"D" ((long)(arg5)),				\
              "0" ((long)(arg6)));									\
    __syscall_return(type,__res);									\
    }

```

x86 架构与我们之前看到的 PowerPC 非常不同。与 RISC PowerPC 相比，x86 被归类为 CISC 处理器，并且寄存器的数量大大减少。

首先看一下最简单的`_syscall0`宏。它只是调用 int 指令的值为 0x80。该指令使 CPU 上升中断 0x80，它将跳转到处理内核中系统调用的代码。

我们可以开始检查如何使用较长的宏传递参数。注意 PowerPC 实现如何向下级联宏，每次添加一个参数。此实现稍微复制了一些代码，但更容易理解。

x86 寄存器名称基于字母，而不是 PowerPC 的基于数字的寄存器名称。我们可以从零参数宏看到只有 A 寄存器被加载;从这里我们可以看出系统调用号在 EAX 寄存器中是预期的。当我们开始在其他宏中加载寄存器时，您可以在`__asm__`调用的参数中看到寄存器的短名称。

我们在`__syscall6`中看到了一些更有趣的东西，宏取 6 个参数。注意推送和弹出说明？它们与 x86 上的堆栈一起工作，将值“推”到内存中的堆栈顶部，然后将堆栈中的值弹回到内存中。因此，在有六个寄存器的情况下，我们需要将 ebp 寄存器的值存储在内存中，将我们的参数放入（mov 指令）中，进行系统调用，然后将原始值恢复为 ebp。在这里你可以看到没有足够的寄存器的缺点;store 到内存是昂贵的，所以越多，你可以避免它们，越好。

您可能会注意到的另一件事就是我们之前在 PowerPC 上看到的内存栅栏指令。这是因为在 x86 上，所有指令的效果将保证在完成时可见。这对编译器（和程序员）来说更容易编程，但灵活性较低。

唯一要做的就是返回值。在 PowerPC 上，我们有两个带内核返回值的寄存器，一个带有值，另一个带有错误代码。但是在 x86 上我们只有一个传递给`__syscall_return`的返回值。该宏将返回值强制转换为 unsigned long，并将其与可能表示错误代码的负值的（依赖于体系结构和内核的）范围进行比较（请注意，errno 值为正，因此内核的否定结果被否定）。但是，这意味着系统调用不能返回小的负值，因为它们与错误代码无法区分。某些具有此要求的系统调用（例如 getpriority（））会为其返回值添加偏移量以强制它始终为正;由用户空间来实现这一点并减去这个常量值以回到“真实”值。
