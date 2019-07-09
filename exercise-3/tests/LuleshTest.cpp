#include <flit.h>

#include <string>

#include <cmath>

// rename main() to avoid name clash
#define main lulesh_main
#include "lulesh.cc"
#undef main
FLIT_REGISTER_MAIN(lulesh_main);

namespace {
double get_val(const std::string contents, const std::string label) {
  auto label_pos = contents.find(label);
  auto number_pos = contents.find_first_of("0123456789", label_pos);
  auto end_pos = contents.find_first_of("\n \t\r", number_pos);
  return std::stod(contents.substr(number_pos, end_pos - number_pos));
}
} // end of unnamed namespace

template <typename T>
class LuleshTest : public flit::TestBase<T> {
public:
  LuleshTest(std::string id) : flit::TestBase<T>(std::move(id)) {}

  virtual size_t getInputsPerRun() override { return 0; }
  virtual std::vector<T> getDefaultInput() override { return { }; }

  virtual long double compare(const std::string &ground_truth,
                              const std::string &test_results) const override
  {
    auto gt_max_abs_diff   = get_val(ground_truth, "MaxAbsDiff");
    auto gt_total_abs_diff = get_val(ground_truth, "TotalAbsDiff");
    auto gt_max_rel_diff   = get_val(ground_truth, "MaxRelDiff");
    auto tr_max_abs_diff   = get_val(test_results, "MaxAbsDiff");
    auto tr_total_abs_diff = get_val(test_results, "TotalAbsDiff");
    auto tr_max_rel_diff   = get_val(test_results, "MaxRelDiff");

    auto abs_err = std::abs(gt_max_abs_diff - tr_max_abs_diff)
                 + std::abs(gt_total_abs_diff - tr_total_abs_diff)
                 + std::abs(gt_max_rel_diff - tr_max_rel_diff);

    auto gt_size = std::abs(gt_max_abs_diff)
                 + std::abs(gt_total_abs_diff)
                 + std::abs(gt_max_rel_diff);

    auto rel_err = abs_err / gt_size;

    return rel_err;
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
flit::Variant LuleshTest<double>::run_impl(const std::vector<double> &ti) {
  FLIT_UNUSED(ti);

  auto result = flit::call_mpi_main(lulesh_main,
      "mpirun -n 1 --bind-to none", "lulesh2.0", "-i 10");

  std::ostream &out = flit::info_stream;
  out << id << " stdout: " << result.out << "\n";
  out << id << " stderr: " << result.err << "\n";
  out << id << " return: " << result.ret << "\n";

  if (result.ret != 0) {
    throw std::logic_error("Failed to run lulesh_main() correctly");
  }

  return result.out;
}

REGISTER_TYPE(LuleshTest)
