

#include "flit.h"

#include <string>
#include <cmath>




#define main flit_mfem_example_13p_main
#include "ex13p.cpp"
#undef main
FLIT_REGISTER_MAIN(flit_mfem_example_13p_main);





template <typename T>
class flit_mfem_example_13p : public flit::TestBase<T> {
public:
  flit_mfem_example_13p(std::string id) : flit::TestBase<T>(std::move(id)) {}
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
    FLIT_UNUSED(ti);
    return flit::Variant();
  }

protected:
  using flit::TestBase<T>::id;
};

template<>
flit::Variant flit_mfem_example_13p<double>::run_impl(const std::vector<double> &ti) {
  FLIT_UNUSED(ti);

  // Make a temporary directory to run in
  std::string start_dir = flit::fsutil::curdir();
  flit::fsutil::TempDir exec_dir;
  flit::fsutil::PushDir pusher(exec_dir.name());

  // run the example's main
  auto result = flit::call_mpi_main(
                     flit_mfem_example_13p_main,
                     "mpirun -n 1 --bind-to none",
                     "flit_mfem_example_13p",
                     "--no-visualization --mesh "
                       + flit::fsutil::join(start_dir, "data", "beam-tet.mesh"));

  std::ostream &out = flit::info_stream;
  out << id << " stdout: " << result.out << "\n";
  out << id << " stderr: " << result.err << "\n";
  out << id << " return: " << result.ret << "\n";
  out.flush();

  if (result.ret != 0) {
    throw std::logic_error("Failed to run my main correctly");
  }

  // We will be returning a vec of strings that hold the mesh data
  std::vector<std::string> retval;

  // Get the mesh
  ostringstream mesh_name;
  mesh_name << "mesh." << setfill('0') << setw(6) << 0;
  std::string mesh_str = flit::fsutil::readfile(mesh_name.str());
  retval.emplace_back(mesh_str);

  // Get calculated values
  for (int i=0; i<5 ; i++) {
    ostringstream mode_name;
    mode_name << "mode_" << setfill('0') << setw(2) << i << "."
              << setfill('0') << setw(6) << 0;
    std::string mode_str = flit::fsutil::readfile(mode_name.str());

    retval.emplace_back(mode_str);
  }

  return flit::Variant(retval);
}

REGISTER_TYPE(flit_mfem_example_13p)
