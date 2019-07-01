#include "flit.h"

#include <string>
#include <cmath>

// Redefine main() to avoid name clash.  This is the function we will test
#define main mfem_13p_main
#include "ex13p.cpp"
#undef main
// Register it so we can use it in call_main() or call_mpi_main()
FLIT_REGISTER_MAIN(mfem_13p_main);


template <typename T>
class Mfem13 : public flit::TestBase<T> {
public:
  Mfem13(std::string id) : flit::TestBase<T>(std::move(id)) {}
  virtual size_t getInputsPerRun() override { return 0; }
  virtual std::vector<T> getDefaultInput() override { return { }; }

  virtual long double compare(const std::vector<std::string> &ground_truth,
                              const std::vector<std::string> &test_results) const override {
    // Read base mesh
    std::istringstream gt_meshreader(ground_truth[0]);
    mfem::Mesh gt_mesh(gt_meshreader);

    std::istringstream tr_meshreader(test_results[0]);
    mfem::Mesh tr_mesh(tr_meshreader);

    // Read eigenmodes and compute error
    //   Error per mode is L2(ground_truth - test_result) / L2(ground_truth)
    //   We return the average of this
    long double nume = 0;
    long double deno = 0;
    for (int i=1; i<2; i++) {
      std::istringstream gt_modereader(ground_truth[i]);
      mfem::GridFunction gt_mode(&gt_mesh, gt_modereader);

      deno += gt_mode.Norml2();

      std::istringstream tr_modereader(test_results[i]);
      mfem::GridFunction tr_mode(&tr_mesh, tr_modereader);

      mfem::GridFunction diff(gt_mode);
      diff -= tr_mode;
      nume += diff.Norml2();
    }

    return nume / deno;
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

// Only implement the test for double precision
template<>
flit::Variant Mfem13<double>::run_impl(const std::vector<double> &ti) {
  FLIT_UNUSED(ti);

  // Run in a temporary directory so output files don't clash
  std::string start_dir = flit::fsutil::curdir();
  flit::fsutil::TempDir exec_dir;
  flit::fsutil::PushDir pusher(exec_dir.name());

  // Run the example's main under MPI
  auto meshfile = flit::fsutil::join(start_dir, "data", "beam-tet.mesh");
  auto result = flit::call_mpi_main(
                     mfem_13p_main,
                     "mpirun -n 1 --bind-to none",
                     "Mfem13",
                     "--no-visualization --mesh " + meshfile);

  // Output debugging information
  std::ostream &out = flit::info_stream;
  out << id << " stdout: " << result.out << "\n";
  out << id << " stderr: " << result.err << "\n";
  out << id << " return: " << result.ret << "\n";
  out.flush();

  if (result.ret != 0) {
    throw std::logic_error("Failed to run my main correctly");
  }

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

REGISTER_TYPE(Mfem13)
