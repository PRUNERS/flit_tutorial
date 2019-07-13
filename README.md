# PEARC FLiT Exercises

FLiT is a unique tool that measures the effect of compiler optimizations on
your numerical code.  These measurements can identify where optimizations
significantly impact susceptible algorithms.

Not only can FLiT identify which compilations cause variability and by how
much, FLiT can help locate where in your code the variability originates, to
the function-level granularity.

We will go through three exercises for using FLiT.

1. The MFEM library.  We use their example 13 in a FLiT test and we will run a
   number of compilations, measuring variability and performance.
2. The MFEM library again.  We choose one variability-inducing compilation and
   continue by identifying where in the MFEM code the variability originates
   down to the function-level using FLiT Bisect.
3. The LULESH mini-application.  We will run through the entire workflow.  When
   we get to using FLiT Bisect, we will use the functionality of running
   through all of the variability compilations found in the first step.


## Setup

For the tutorial, setup has already been performed.  If you are running this
outside of the tutorial, a `setup.sh` script is provided to download and
compile the source code of the example packages for each exercise.

```bash
$ bash setup.sh
```

This does not, however, download or install FLiT.  For that, please go to the
[FLiT GitHub Repository](https://github.com/PRUNERS/FLiT.git) for details on
how to build, install, and use FLiT.


## Exercise-1: MFEM Variability

The files for this tutorial exercise can be found in `exercise-1/`.


### Deep Dive Into The FLiT Test Implementation

MFEM is a finite-element library.  It's a good use-case for identifying
floating-point variability from compier optimizations.

It comes with a large number of examples of how to run finite-element
simulations.  For this tutorial, we will use their example #13.  Let's take a
look at how the FLiT test looks.  It is in `exercise-1/tests/Mfem13.cpp`

```c++
// Redefine main() to avoid name clash.  This is the function we will test
#define main mfem_13p_main
#include "ex13p.cpp"
#undef main
// Register it so we can use it in call_main() or call_mpi_main()
FLIT_REGISTER_MAIN(mfem_13p_main);
```

Since the MFEM example uses `main()`, unless we want to change the source file
to change the name, this is a gimicky trick to avoid name clashes of that
`main()` function and the flit test's `main()` function.  In order to call it
from the test function under a separate process, we need to register this newly
named function with flit using `FLIT_REGISTER_MAIN()`.

```c++
template <typename T>
class Mfem13 : public flit::TestBase<T> {
public:
  Mfem13(std::string id) : flit::TestBase<T>(std::move(id)) {}
  virtual size_t getInputsPerRun() override { return 0; }
  virtual std::vector<T> getDefaultInput() override { return { }; }

  virtual long double compare(const std::vector<std::string> &ground_truth,
                              const std::vector<std::string> &test_results)
  const override {
    [...]
  }

protected:
  virtual flit::Variant run_impl(const std::vector<T> &ti) override {
    // Empty test for the general case
    FLIT_UNUSED(ti);
    return flit::Variant();
  }

protected:
  using flit::TestBase<T>::id;
};
```

This is pretty much an empty test case, one that takes no floating-point
values, since we're just going to call the `main()` function anyway.  We're
skipping the details of the `compare()` function.  Suffice it to say, the
results are meshes with values, and the `compare()` function performs an
$\ell_2$ norm between the two sets of results.

Now, let's take a look at the actual test implementation:

```c++
// Only implement the test for double precision
template<>
flit::Variant Mfem13<double>::run_impl(const std::vector<double> &ti) {
  FLIT_UNUSED(ti);

  // Run in a temporary directory so output files don't clash
  std::string start_dir = flit::fsutil::curdir();
  flit::fsutil::TempDir exec_dir;
  flit::fsutil::PushDir pusher(exec_dir.name());
```

The test starts out by creating a temporary directory and going into it.  But
in classic RAII style, when those objects are destroyed by scoping, it will
automatically destroy the temporary directory and bring us back to where we
were when we entered this function.

Also of note, is that we only implement the `double` precision type for the
`run_impl()` function.  The other precisions are using the empty definition
above in the class, which essentially disables those precisions.

```c++
  // Run the example's main under MPI
  auto meshfile = flit::fsutil::join(start_dir, "data", "beam-tet.mesh");
  auto result = flit::call_mpi_main(
                     mfem_13p_main,
                     "mpirun -n 1 --bind-to none",
                     "Mfem13",
                     "--no-visualization --mesh " + meshfile);
```

Next, we call the `mfem_13p_main()` function in a child process under MPI with
only one MPI process.  We could use more processes and even across more nodes,
but we kept it simple for this tutorial.  We specify the commmand-line
arguments to be given to `mfem_13p_main()`.

```c++
  // Output debugging information
  std::ostream &out = flit::info_stream;
  out << id << " stdout: " << result.out << "\n";
  out << id << " stderr: " << result.err << "\n";
  out << id << " return: " << result.ret << "\n";
  out.flush();

  if (result.ret != 0) {
    throw std::logic_error("Failed to run my main correctly");
  }
```

Next, we do some logging and error checking.  Nothing too interesting here.  It
demonstrates what kind of information is returned from `call_mpi_main()` and
likewise from `call_main()`.

```c++
  // We will be returning a vector of strings that hold the mesh data
  std::vector<std::string> retval;

  // Get the mesh
  ostringstream mesh_name;
  mesh_name << "mesh." << setfill('0') << setw(6) << 0;
  std::string mesh_str = flit::fsutil::readfile(mesh_name.str());
  retval.emplace_back(mesh_str);

  // Read calculated values
  for (int i = 0; i < 5 ; i++) {
    ostringstream mode_name;
    mode_name << "mode_" << setfill('0') << setw(2) << i << "."
              << setfill('0') << setw(6) << 0;
    std::string mode_str = flit::fsutil::readfile(mode_name.str());

    retval.emplace_back(mode_str);
  }

  // Return the mesh and mode files as strings
  return flit::Variant(retval);
}
```

We now create a `std::vector<std::string>` containing the contents of each
output file from calling the `mfem_13p_main()` function (which was the new name
we gave the `main()` function from `ex13p.cpp` of the MFEM examples).  This is
the value we return from the test, and is then given to the `compare()`
function above that compares with the $\ell_2$ norm.

```c++
REGISTER_TYPE(Mfem13)
```

Lastly, we register this test with FLiT so that it can actually be called and
run.


### FLiT Configuration

Let's understand a bit about how this project is configured to understand how
to use FLiT.  There are two configuration files for a set of FLiT tests

- `flit-config.toml`: contains configuration about compilers and the
  compilation search space.  There are other settings in there too.
- `custom.mk`: an included makefile into the autogenerated `Makefile`.  This
  contains information about how to compile the tests, such as source files,
  include paths, and linker flags.

Looking first at `exercise-1/flit-config.toml`:

```ini
[run]
enable_mpi = true
```

Needed in order to include MPI compiler and linker flags.

```ini
[dev_build]
compiler_name = 'g++'
optimization_level = '-O3'
switches = '-mavx2 -mfma'
```

Defines the compilation used for the `make dev` target.

```ini
[ground_truth]
compiler_name = 'g++'
optimization_level = '-O2'
switches = ''
```

Likewise, defines the compilation used for the `make gt` target.

```ini
[[compiler]]
binary = 'g++-7'
name = 'g++'
type = 'gcc'
optimization_levels = [
    '-O3',
]
switches_list = [
    '-ffast-math',
    '-funsafe-math-optimizations',
    '-mfma',
]
```

Defines the `g++` compiler and its search space of optimization levels and
flags.  We keep it short for this tutorial for the sake of time.

```ini
[[compiler]]
binary = 'clang++-6.0'
name = 'clang++'
type = 'clang'
optimization_levels = [
    '-O3',
]
switches_list = [
    '-ffast-math',
    '-funsafe-math-optimizations',
    '-mfma',
]
```

Defines the `clang++` compiler and its search space of optimization levels and
flags.  Again, kept short for the sake of time.

And that concludes the configurations we used for this tutorial exercise.
There are other options that can be put into the file, which we deleted and
fall back to the default values.

Now, to look at `exercise-1/custom.mk`:

```make
PACKAGES_DIR   := $(abspath ../packages)
MFEM_SRC       := $(PACKAGES_DIR)/mfem
HYPRE_SRC      := $(PACKAGES_DIR)/hypre
METIS_SRC      := $(PACKAGES_DIR)/metis-4.0

SOURCE         :=
SOURCE         += $(wildcard *.cpp)
SOURCE         += $(wildcard tests/*.cpp)

# Compiling all sources of MFEM into the tests takes too long for a tutorial
# skip it.  Instead, we link in the MFEM static library
#SOURCE         += $(wildcard ${MFEM_SRC}/fem/*.cpp)
#SOURCE         += $(wildcard ${MFEM_SRC}/general/*.cpp)
#SOURCE         += $(wildcard ${MFEM_SRC}/linalg/*.cpp)
#SOURCE         += $(wildcard ${MFEM_SRC}/mesh/*.cpp)

# just the one source file to see there is a difference
SOURCE         += ${MFEM_SRC}/linalg/densemat.cpp  # where the bug is

CC_REQUIRED    += -I${MFEM_SRC}
CC_REQUIRED    += -I${MFEM_SRC}/examples
CC_REQUIRED    += -isystem ${HYPRE_SRC}/src/hypre/include

LD_REQUIRED    += -L${MFEM_SRC} -lmfem
LD_REQUIRED    += -L${HYPRE_SRC}/src/hypre/lib -lHYPRE
LD_REQUIRED    += -L${METIS_SRC} -lmetis
```

That is the entire `custom.mk` file for this tutorial exercise.  It begins by
specifying all of the source files to include in the compilation.  Notice that
the majority of them are commented out, simply for the sake of time.  It is for
this reason that we include `libmfem.a` in the link flags to bring in any
object files we did not compile into the test executable.

The `CC_REQUIRED` and `LD_REQUIRED` variables contain the compiler flags (e.g.,
include paths) and linker flags (e.g., shared libraries) needed by the
compilation.

With that, we have completely configured FLiT to work with this test and we are
ready to go.


### Full FLiT Run

Let's now change into the `exercise-1` directory:

```bash
$ cd exercise-1/
$ ls
custom.mk  data  flit-config.toml  main.cpp  tests
```

The autogenerated Makefile may not be in your `exercise-1` directory.  This is
because it will be regenerated.  For that reason, you will not want to commit
it to your version control system.  Let's regenerate it now.

```bash
$ flit update
Creating ./Makefile
```

The first step with FLiT is to take your tests, and compile all versions
specified by your search space.  I personally prefer to do this in two separate
steps:

1. Create all of the compilations
2. Run them all

This is simply because when we run them, we want to be a little bit more
careful to not interfere with timing measurements, whereas creating
compilations, we will generally use as many resources as our machines can
muster.

To create all of the compilations:

```bash
$ make runbuild -j1
  mkdir obj/gt
  /home/user1/Module-FLiT/packages/mfem/linalg/densemat.cpp -> obj/gt/densemat.cpp.o
  main.cpp -> obj/gt/main.cpp.o
  tests/Mfem13.cpp -> obj/gt/Mfem13.cpp.o
Building gtrun
  mkdir bin
  mkdir obj/GCC_ip-172-31-8-101_FFAST_MATH_O3
  /home/user1/Module-FLiT/packages/mfem/linalg/densemat.cpp -> obj/GCC_ip-172-31-8-101_FFAST_MATH_O3/densemat.cpp.o
[...]
```

(takes approximately 1 minute)

_Note: For more verbose output, you can use `VERBOSE=1` with the make
commands._

You will probably want more processes than 1, but for this tutorial exercise,
we will stick to this in order to be nice to others using the same machine.

This command will put object files in the `obj/` directory and compiled
executables inside the `bin/` directory.

Now, to run the tests and generate results:

```bash
$ make run -j1
  mkdir results
  gtrun -> ground-truth.csv
  results/GCC_ip-172-31-8-101_FFAST_MATH_O3-out -> results/GCC_ip-172-31-8-101_FFAST_MATH_O3-out-comparison.csv
  results/GCC_ip-172-31-8-101_FUNSAFE_MATH_OPTIMIZATIONS_O3-out -> results/GCC_ip-172-31-8-101_FUNSAFE_MATH_OPTIMIZATIONS_O3-out-comparison.csv
  results/GCC_ip-172-31-8-101_MFMA_O3-out -> results/GCC_ip-172-31-8-101_MFMA_O3-out-comparison.csv
  results/CLANG_ip-172-31-8-101_FFAST_MATH_O3-out -> results/CLANG_ip-172-31-8-101_FFAST_MATH_O3-out-comparison.csv
  results/CLANG_ip-172-31-8-101_FUNSAFE_MATH_OPTIMIZATIONS_O3-out -> results/CLANG_ip-172-31-8-101_FUNSAFE_MATH_OPTIMIZATIONS_O3-out-comparison.csv
  results/CLANG_ip-172-31-8-101_MFMA_O3-out -> results/CLANG_ip-172-31-8-101_MFMA_O3-out-comparison.csv
```

(takes approximately 1 minute)

Here, you will typically want to, at most, run as many processes as processors
you have so that they do not interfere with each other with regards to timing.
Each test will be run at least three times in order to get a more accurate
timing measurement.

This command will execute the tests and put the results within a `results/`
directory.


### Analyzing FLiT Results

The next step is to create a results database from the CSV files output from
each test:

```bash
$ flit import --label "First FLiT Results" results/*.csv
Creating results.sqlite
Importing results/CLANG_[...]_FFAST_MATH_O3-out-comparison.csv
Importing results/CLANG_[...]_FUNSAFE_MATH_OPTIMIZATIONS_O3-out-comparison.csv
Importing results/CLANG_[...]_MFMA_O3-out-comparison.csv
Importing results/GCC_[...]_FFAST_MATH_O3-out-comparison.csv
Importing results/GCC_[...]_FUNSAFE_MATH_OPTIMIZATIONS_O3-out-comparison.csv
Importing results/GCC_[...]_MFMA_O3-out-comparison.csv
```

We have now created a sqlite3 database with all of our results called
`results.sqlite`.  The label is optional but recommended.

```bash
$ sqlite3 results.sqlite
SQLite version 3.28.0 2019-04-16 19:49:53
Enter ".help" for usage hints.
sqlite> .tables
runs   tests
sqlite> .headers on
sqlite> .mode column
sqlite> select * from runs;
id          rdate                       label                     
----------  --------------------------  ------------------
1           2019-07-08 23:05:19.358055  First FLiT Results
```

There are two tables, and the `runs` table only logs when the run was imported
and the given label.

```bash
sqlite> select * from tests;
id          run         name        host             compiler     optl        switches     precision   comparison_hex       comparison  file                                 nanosec   
----------  ----------  ----------  ---------------  -----------  ----------  -----------  ----------  -------------------  ----------  -----------------------------------  ----------
1           1           Mfem13      ip-172-31-8-101  clang++-6.0  -O3         -ffast-math  d           0x00000000000000000  0.0         CLANG_ip-172-31-8-101_FFAST_MATH_O3  2857386994
2           1           Mfem13      ip-172-31-8-101  clang++-6.0  -O3         -funsafe-ma  d           0x00000000000000000  0.0         CLANG_ip-172-31-8-101_FUNSAFE_MATH_  2853588952
3           1           Mfem13      ip-172-31-8-101  clang++-6.0  -O3         -mfma        d           0x00000000000000000  0.0         CLANG_ip-172-31-8-101_MFMA_O3        2858789982
4           1           Mfem13      ip-172-31-8-101  g++-7        -O3         -ffast-math  d           0x00000000000000000  0.0         GCC_ip-172-31-8-101_FFAST_MATH_O3    2841191528
5           1           Mfem13      ip-172-31-8-101  g++-7        -O3         -funsafe-ma  d           0x00000000000000000  0.0         GCC_ip-172-31-8-101_FUNSAFE_MATH_OP  2868636192
6           1           Mfem13      ip-172-31-8-101  g++-7        -O3         -mfma        d           0x4006c101e1c5965d6  193.007351  GCC_ip-172-31-8-101_MFMA_O3          2797305220
```

Whoa, that's a lot.  Let's just pick a few columns that actually have
information we care about.

```bash
sqlite> select compiler, optl, switches, comparison, nanosec from tests;
compiler     optl        switches     comparison  nanosec   
-----------  ----------  -----------  ----------  ----------
clang++-6.0  -O3         -ffast-math  0.0         2857386994
clang++-6.0  -O3         -funsafe-ma  0.0         2853588952
clang++-6.0  -O3         -mfma        0.0         2858789982
g++-7        -O3         -ffast-math  0.0         2841191528
g++-7        -O3         -funsafe-ma  0.0         2868636192
g++-7        -O3         -mfma        193.007351  2797305220
sqlite> .q
```

That's better.  Unfortunately, some of the switches are getting cut off, but oh
well.  It's enough that we recognize what flag it is from our search space.

Looking at the `nanosec` column, they all have very similar timings.  The
differences in optimizations did not change very much with regards to timing.
But that last row had a significant comparison value!  If you recall, the
`comparison()` function from the test gives us a relative error accross the
mesh using the $\ell_2$ norm.  That means that last row has 193% relative
error!  That's huge!  Looking at the compilation of `g++-7 -O3 -mfma`, we can
reasonably guess that the introduction of FMA instructions led to this change.

Can we find out which function(s) introduce this variability when FMA is
introduced?


## Exercise-2: MFEM Bisect

With FLiT Bisect, we can identify the file and function sites within your code
base where variability is introduced.

For this exercise, we will go into a different directory:

```bash
$ cd ../exercise-2/
```

The only thing different in this directory is `custom.mk`

```bash
$ diff -u ../exercise-1/custom.mk ./custom.mk
--- ../exercise-1/custom.mk	2019-07-01 16:09:39.239923037 -0600
+++ ./custom.mk	2019-07-01 16:07:41.090571010 -0600
@@ -17,9 +17,15 @@
 #SOURCE         += $(wildcard ${MFEM_SRC}/linalg/*.cpp)
 #SOURCE         += $(wildcard ${MFEM_SRC}/mesh/*.cpp)
 
-# just the one source file to see there is a difference
 SOURCE         += ${MFEM_SRC}/linalg/densemat.cpp  # where the bug is
 
+# a few more files to make the search space a bit more interesting
+SOURCE         += ${MFEM_SRC}/linalg/matrix.cpp
+SOURCE         += ${MFEM_SRC}/fem/gridfunc.cpp
+SOURCE         += ${MFEM_SRC}/fem/linearform.cpp
+SOURCE         += ${MFEM_SRC}/mesh/point.cpp
+SOURCE         += ${MFEM_SRC}/mesh/quadrilateral.cpp
+
 CC_REQUIRED    += -I${MFEM_SRC}
 CC_REQUIRED    += -I${MFEM_SRC}/examples
 CC_REQUIRED    += -isystem ${HYPRE_SRC}/src/hypre/include
```

We just add five more random MFEM source files to make the search a bit more
interesting.  The comment in the `custom.mk` file gives away already which file
generates the variability.  But let's pretend we don't know which file it is.
MFEM has 155 source files and approximately 3,000 functions.  If we included
all of it, the search is definitely non-trivial.  For the sake of time, we
simplified this to a search space of 8 files (6 MFEM source files, `main.cpp`,
and the `Mfem13.cpp` FLiT test file).

Before we can begin, we need to generate the `Makefile`, since we have moved into yet another FLiT test directory:

```bash
$ flit update
Creating ./Makefile
```

Remember, the compilation that caused the variability was `g++-7 -O3 -mfma`.  FLiT Bisect requires at least three pieces of information:

1. The precision to use (e.g., `double`) (remember, our test classes are templated)
2. The compilation causing variability (e.g., `g++-7 -O3 -mfma`)
3. The name of the FLiT test (e.g., `Mfem13`)

Let us use FLiT Bisect to find the site:

```bash
$ flit bisect --precision=double "g++-7 -O3 -mfma" Mfem13
Updating ground-truth results - ground-truth.csv - done
Searching for differing source files:
  Created ./bisect-04/bisect-make-01.mk - compiling and running - score 193.00735125466363
  Created ./bisect-04/bisect-make-02.mk - compiling and running - score 193.00735125466363
  Created ./bisect-04/bisect-make-03.mk - compiling and running - score 0.0
  Created ./bisect-04/bisect-make-04.mk - compiling and running - score 193.00735125466363
    Found differing source file /home/user1/Module-FLiT/packages/mfem/linalg/densemat.cpp: score 193.00735125466363
  Created ./bisect-04/bisect-make-05.mk - compiling and running - score 0.0
  Created ./bisect-04/bisect-make-06.mk - compiling and running - score 0.0
all variability inducing source file(s):
  /home/user1/Module-FLiT/packages/mfem/linalg/densemat.cpp (score 193.00735125466363)
Searching for differing symbols in: /home/user1/Module-FLiT/packages/mfem/linalg/densemat.cpp
  Created ./bisect-04/bisect-make-07.mk - compiling and running - score 193.00735125466363
  Created ./bisect-04/bisect-make-08.mk - compiling and running - score 0.0
  Created ./bisect-04/bisect-make-09.mk - compiling and running - score 193.00735125466363
  Created ./bisect-04/bisect-make-10.mk - compiling and running - score 0.0
  Created ./bisect-04/bisect-make-11.mk - compiling and running - score 193.00735125466363
  Created ./bisect-04/bisect-make-12.mk - compiling and running - score 0.0
  Created ./bisect-04/bisect-make-13.mk - compiling and running - score 0.0
  Created ./bisect-04/bisect-make-14.mk - compiling and running - score 0.0
  Created ./bisect-04/bisect-make-15.mk - compiling and running - score 0.0
  Created ./bisect-04/bisect-make-16.mk - compiling and running - score 193.00735125466363
    Found differing symbol on line 3692 -- mfem::AddMult_a_AAt(double, mfem::DenseMatrix const&, mfem::DenseMatrix&) (score 193.00735125466363)
  Created ./bisect-04/bisect-make-17.mk - compiling and running - score 0.0
  Created ./bisect-04/bisect-make-18.mk - compiling and running - score 0.0
  All differing symbols in /home/user1/Module-FLiT/packages/mfem/linalg/densemat.cpp:
    line 3692 -- mfem::AddMult_a_AAt(double, mfem::DenseMatrix const&, mfem::DenseMatrix&) (score 193.00735125466363)
All variability inducing symbols:
  /home/user1/Module-FLiT/packages/mfem/linalg/densemat.cpp:3692 _ZN4mfem13AddMult_a_AAtEdRKNS_11DenseMatrixERS0_ -- mfem::AddMult_a_AAt(double, mfem::DenseMatrix const&, mfem::DenseMatrix&) (score 193.00735125466363)
```

(takes approximately 1 minute 30 seconds)

That's all there is to it.  FLiT Bisect first searches over files and it found
`mfem/linalg/densemat.cpp` to be the only file contributing to variability.
Then it searched over functions (which it calls symbols since it is performed
after compilation), and FLiT Bisect found only one function,
`mfem::AddMult_a_AAt()` on line 3,692 of `mfem/linalg/densemat.cpp`.  Sweet!

Let's now take a look at that function:

```bash
$ cat -n ../packages/mfem/linalg/densemat.cpp | tail -n +3680 | head -n 40
  3680	         {
  3681	            d += A(k, i) * B(k, j);
  3682	         }
  3683	         AtB(i, j) = d;
  3684	      }
  3685	#endif
  3686	}
  3687	
  3688	void AddMult_a_AAt(double a, const DenseMatrix &A, DenseMatrix &AAt)
  3689	{
  3690	   double d;
  3691	
  3692	   for (int i = 0; i < A.Height(); i++)
  3693	   {
  3694	      for (int j = 0; j < i; j++)
  3695	      {
  3696	         d = 0.;
  3697	         for (int k = 0; k < A.Width(); k++)
  3698	         {
  3699	            d += A(i,k) * A(j,k);
  3700	         }
  3701	         AAt(i, j) += (d *= a);
  3702	         AAt(j, i) += d;
  3703	      }
  3704	      d = 0.;
  3705	      for (int k = 0; k < A.Width(); k++)
  3706	      {
  3707	         d += A(i,k) * A(i,k);
  3708	      }
  3709	      AAt(i, i) += a * d;
  3710	   }
  3711	}
  3712	
  3713	void Mult_a_AAt(double a, const DenseMatrix &A, DenseMatrix &AAt)
  3714	{
  3715	   for (int i = 0; i < A.Height(); i++)
  3716	      for (int j = 0; j <= i; j++)
  3717	      {
  3718	         double d = 0.;
  3719	         for (int k = 0; k < A.Width(); k++)
```

It is not a very big function, and looking closely, it just computes:

\begin{equation}
 M = M + a A A^T
\end{equation}

where $M$ here is called `AAt` in the code and all variables except for $a$ are
dense matrices.

Since this tutorial is not about numerical analysis or finite-element, we stop
here.  We would give this to the numerical analysts or scientists responsible
for the algorithm to understand why FMA here causes such ruckus with our
finite-element code.


## Exercise-3: LULESH Auto-Bisect

For this exercise, we will go into a different directory:

```bash
$ cd ../exercise-3/
```

This is now related to a different code project -- LULESH.  We will not look
into the configuration too much, it is very similar to the MFEM configuration.

You will find an already created `results.sqlite` database.  Since we have already demonstrated how to generate the results, we figured we didn't want to put you through that again (and we can save time).

Let's look at the results:

```bash
$ sqlite3 results.sqlite 
SQLite version 3.28.0 2019-04-16 19:49:53
Enter ".help" for usage hints.
sqlite> .mode column
sqlite> .headers on
sqlite> select compiler, optl, switches, comparison, nanosec from tests;
compiler     optl        switches           comparison            nanosec   
-----------  ----------  -----------------  --------------------  ----------
clang++-6.0  -O3         -freciprocal-math  5.52511478433538e-05  432218541 
  33 seconds
clang++-6.0  -O3         -funsafe-math-opt  5.52511478433538e-05  432185456 
  33 seconds
clang++-6.0  -O3                            0.0                   433397072 
g++-7        -O3         -freciprocal-math  5.52511478433538e-05  441362811 
  34 seconds
g++-7        -O3         -funsafe-math-opt  7.02432004920159      436202864 
  40 seconds
g++-7        -O3         -mavx2 -mfma       1.02330009691563      416599918 
  19 seconds
g++-7        -O3                            0.0                   432654778 
```

Again, we did not do a large search space.  Only 7 different compilations.  The
timing measurements vary by about 10%, which may be significant enough to
warrent further investigation.

The comparison value is probably not that noteworthy, just the fact that
something changed.

For our final functionality that we wish to demonstrate, we can automatically
run FLiT Bisect on all of the compilations that have a non-zero comparison
value.  But first, we need to generate our `Makefile`:

```bash
$ flit update
Creating ./Makefile
```

Now, let's run FLiT Bisect automatically from the results database file.

```bash
$ flit bisect --auto-sqlite-run ./results.sqlite --parallel 1 --jobs 1
```

Let me explain this commant a bit:

- `--auto-sqlite-run` is given a database file.  It will filter out rows with a
  `comparison` value of 0.0.  Then it will grab the precision, compiler,
  optimization level, and switches and will run bisect.
- `--parallel` specifies how many bisects can be run at the same time.  If you
  are using MPI and you have more nodes than are used by the tests, you can use
  this number to specify how many can be run simultaneously.  On the other
  hand, if your tests are not reentrant (e.g., output to the same files each
  time), then you will need to set this to 1.
- `--jobs` how many processes can be used during compilation.  This is
  converted to `-jN` for GNU Make where N is the number passed to this flag.
  This is only for compilations and not for test executions.

and its output:

```bash
Before parallel bisect run, compile all object files
  (1 of 5) clang++ -O3 -freciprocal-math:  done
  (2 of 5) clang++ -O3 -funsafe-math-optimizations:  done
  (3 of 5) g++ -O3 -freciprocal-math:  done
  (4 of 5) g++ -O3 -funsafe-math-optimizations:  done
  (5 of 5) g++ -O3 -mavx2 -mfma:  done
Updating ground-truth results - ground-truth.csv - done

Run 1 of 5
flit bisect --precision double "clang++ -O3 -freciprocal-math" LuleshTest
Updating ground-truth results - ground-truth.csv - done
Searching for differing source files:
  Created ./bisect-01/bisect-make-01.mk - compiling and running - score 5.525114784335379e-05
  Created ./bisect-01/bisect-make-02.mk - compiling and running - score 0.3327979261374302
  Created ./bisect-01/bisect-make-03.mk - compiling and running - score 0.0
  Created ./bisect-01/bisect-make-04.mk - compiling and running - score 0.3327979261374302
    Found differing source file ../packages/LULESH/lulesh-init.cc: score 0.3327979261374302
  Created ./bisect-01/bisect-make-05.mk - compiling and running - score 0.33294020544031533
  Created ./bisect-01/bisect-make-06.mk - compiling and running - score 0.0
  Created ./bisect-01/bisect-make-07.mk - compiling and running - score 0.0
  Created ./bisect-01/bisect-make-08.mk - compiling and running - score 0.33294020544031533
    Found differing source file tests/LuleshTest.cpp: score 0.33294020544031533
  Created ./bisect-01/bisect-make-09.mk - compiling and running - score 0.0
  Created ./bisect-01/bisect-make-10.mk - compiling and running - score 5.525114784335379e-05
all variability inducing source file(s):
  tests/LuleshTest.cpp (score 0.33294020544031533)
  ../packages/LULESH/lulesh-init.cc (score 0.3327979261374302)
Searching for differing symbols in: tests/LuleshTest.cpp
  Created ./bisect-01/bisect-make-11.mk - compiling and running - score 0.33294020544031533
  Created ./bisect-01/bisect-make-12.mk - compiling and running - score 0.33294020544031533
  Created ./bisect-01/bisect-make-13.mk - compiling and running - score 0.0
[...]
```

(takes about 3 minutes 10 seconds)

FLiT Bisect will first make all compilations before running any Bisect steps in
order to eliminate race conditions.  Then the regular bisect occurs.

We won't go through the results here, but FLiT Bisect identifies each site of
variability from these five variability compilations specified in
`results.sqlite`.

The final results can be seen in `all-bisect.csv` which can be mined.

```c++
$ head -n 3 auto-bisect.csv 
testid,bisectnum,compiler,optl,switches,precision,testcase,type,name,return
1,1,clang++,-O3,-freciprocal-math,double,LuleshTest,completed,"lib,src,sym",0
1,1,clang++,-O3,-freciprocal-math,double,LuleshTest,src,"('tests/LuleshTest.cpp', 0.33294020544031533)",0
```

_Note: if you don't want to run all rows with non-zero values, you can copy the
database, and perform your own filtering to remove any rows you don't want
explored.  You can then pass this stripped down database file to auto-bisect to
explore only the compilations of interest._


### Bonus: Find $k$ Biggest Contributors

There is another version of FLiT Bisect that can find the $k$ biggest
contributors to your variability.  Let's explore this a little, time
permitting.

If we look closer at the FLiT Bisect results from just previously, we see that
run 4 had five function sites.

```
Run 4 of 5
flit bisect --precision double "g++ -O3 -funsafe-math-optimizations" LuleshTest
Updating ground-truth results - ground-truth.csv - done
Searching for differing source files:
  [...]
all variability inducing source file(s):
  ../packages/LULESH/lulesh-init.cc (score 3.7609285311270604)
  tests/LuleshTest.cpp (score 0.022750390077923448)
Searching for differing symbols in: ../packages/LULESH/lulesh-init.cc
  [...]
All variability inducing symbols:
  ../packages/LULESH/lulesh-init.cc:16 _ZN6DomainC1Eiiiiiiiii -- Domain::Domain(int, int, int, int, int, int, int, int, int) (score 2.3302358973548727)
  ../packages/LULESH/lulesh-init.cc:219 _ZN6Domain9BuildMeshEiii -- Domain::BuildMesh(int, int, int) (score 1.4315005606175104)
  ../packages/LULESH/lulesh.cc:1362 _Z14CalcElemVolumePKdS0_S0_ -- CalcElemVolume(double const*, double const*, double const*) (score 0.9536115035892543)
  ../packages/LULESH/lulesh.cc:1507 _Z22CalcKinematicsForElemsR6Domaindi -- CalcKinematicsForElems(Domain&, double, int) (score 0.665781828022106)
  ../packages/LULESH/lulesh.cc:2651 _Z11lulesh_mainiPPc -- lulesh_main(int, char**) (score 0.3328909140110529)
```

These results took 34 compilation and test run cycles to identify.  What if we
only wanted the top 1 contributor to variability?  Can we do better?  Maybe...

Let's rerun that FLiT Bisect run but with this alternative algorithm, saying we
are only interested in the one top contributor.  We do this with the
`--biggest` flag (or `-k` for short).

```bash
$ flit bisect --biggest=1 --precision=double "g++-7 -O3 -funsafe-math-optimizations" LuleshTest
Updating ground-truth results - ground-truth.csv - done
Looking for the top 1 different symbol(s) by starting with files
  Created ./bisect-06/bisect-make-01.mk - compiling and running - score 7.024320049201593
  Created ./bisect-06/bisect-make-02.mk - compiling and running - score 3.7609285311270604
  Created ./bisect-06/bisect-make-03.mk - compiling and running - score 0.022750390077923448
  Created ./bisect-06/bisect-make-04.mk - compiling and running - score 0.0
  Created ./bisect-06/bisect-make-05.mk - compiling and running - score 3.7609285311270604
  Created ./bisect-06/bisect-make-06.mk - compiling and running - score 3.7609285311270604
  Created ./bisect-06/bisect-make-07.mk - compiling and running - score 0.0
    Found differing source file ../packages/LULESH/lulesh-init.cc: score 3.7609285311270604
    Searching for differing symbols in: ../packages/LULESH/lulesh-init.cc
      Created ./bisect-06/bisect-make-08.mk - compiling and running - score 3.7609285311270604
      Created ./bisect-06/bisect-make-09.mk - compiling and running - score 1.4315005606175104
      Created ./bisect-06/bisect-make-10.mk - compiling and running - score 2.3302358973548727
      Created ./bisect-06/bisect-make-11.mk - compiling and running - score 0.0
      Created ./bisect-06/bisect-make-12.mk - compiling and running - score 2.3302358973548727
      Created ./bisect-06/bisect-make-13.mk - compiling and running - score 0.0
      Created ./bisect-06/bisect-make-14.mk - compiling and running - score 2.3302358973548727
      Created ./bisect-06/bisect-make-15.mk - compiling and running - score 0.0
      Created ./bisect-06/bisect-make-16.mk - compiling and running - score 2.3302358973548727
        Found differing symbol on line 16 -- Domain::Domain(int, int, int, int, int, int, int, int, int) (score 2.3302358973548727)
  Created ./bisect-06/bisect-make-17.mk - compiling and running - score 0.0
  Created ./bisect-06/bisect-make-18.mk - compiling and running - score 0.022750390077923448
  Created ./bisect-06/bisect-make-19.mk - compiling and running - score 0.0
  Created ./bisect-06/bisect-make-20.mk - compiling and running - score 0.022750390077923448
    Found differing source file tests/LuleshTest.cpp: score 0.022750390077923448
The found highest variability inducing source files:
  ../packages/LULESH/lulesh-init.cc (score 3.7609285311270604)
  tests/LuleshTest.cpp (score 0.022750390077923448)
The 1 highest variability symbol:
  ../packages/LULESH/lulesh-init.cc:16 _ZN6DomainC1Eiiiiiiiii -- Domain::Domain(int, int, int, int, int, int, int, int, int) (score 2.3302358973548727)
```

(takes about 16 seconds)

There are a few things to notice that are different here:

1. We did find the biggest contributor: `Domain::Domain()`
2. This took 20 compilation/test run cycles instead of 34
3. Instead of finding all variability files at once, it found one, then
   immediately searched for contributing functions from that file.

This approach uses one further assumption: that the errors are additive.  This
assumption can be violated, but in my experience, it appears to be a good
heuristic.  That makes this approach only approximate.  _To be sure that you
have the biggest contributor, you must search for all contributors._

It is recommended that you use this approach for large code bases to identify
the largest contributor, address it, and then rerun FLiT Bisect to address the
next biggest one.


## Conclusion

That concludes our tutorial exercises.  Please visit the
[FLiT Website](https://pruners.github.io/flit)
to download published papers, slides, and posters.  You can download the code
and documentation from our
[GitHub repository](https://github.com/PRUNERS/FLiT.git).

Please also visit [fpanalysistools.org](http://fpanalysistools.org) for more
information.

