from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]

STUBS = r"""
#include <assert.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#define KERNEL_VERSION(a, b, c) (((a) << 16) + ((b) << 8) + (c))
#define GFP_KERNEL 0
#define IS_ERR(p) ((uintptr_t)(p) >= (uintptr_t)-4095)
#define PTR_ERR(p) ((long)(intptr_t)(p))
#define pr_err(...) fprintf(stderr, __VA_ARGS__)
struct i2c_adapter { int unused; };
struct i2c_client { int address; };
static struct i2c_adapter adapter;
static struct i2c_client clients[8];
static int fail_allocation, fail_adapter, fail_address = -1;
static int allocations, references, registered;
static void *kzalloc(size_t size, int flags)
{
    (void)flags;
    if (fail_allocation) return NULL;
    allocations++;
    return calloc(1, size);
}
static void kfree(void *p) { assert(p); allocations--; free(p); }
static struct i2c_adapter *i2c_get_adapter(int id)
{
    assert(id == 0);
    if (fail_adapter) return NULL;
    references++;
    return &adapter;
}
static void i2c_put_adapter(struct i2c_adapter *p)
{
    assert(p == &adapter);
    references--;
}
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 2, 0)
static struct i2c_client *i2c_new_dummy_device(struct i2c_adapter *p, int address)
#else
static struct i2c_client *i2c_new_dummy(struct i2c_adapter *p, int address)
#endif
{
    assert(p == &adapter);
    assert(address >= 0x20 && address <= 0x27);
    if (address == fail_address) {
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 2, 0)
        return (struct i2c_client *)(intptr_t)-EBUSY;
#else
        return NULL;
#endif
    }
    clients[address - 0x20].address = address;
    registered++;
    return &clients[address - 0x20];
}
static void i2c_unregister_device(struct i2c_client *p)
{
    assert(!IS_ERR(p) && p);
    assert(p >= clients && p < clients + 8);
    registered--;
}
static int i2c_smbus_write_byte_data(struct i2c_client *p, int reg, int value)
{
    (void)p; (void)reg; (void)value;
    return 0;
}
static int i2c_smbus_read_byte_data(struct i2c_client *p, int reg)
{
    (void)p; (void)reg;
    return 0;
}
"""

HARNESS = r"""
int main(void)
{
    struct MCP23017 *m;
    int address;
    fail_allocation = 1;
    assert(mcp23017_init() == NULL);
    fail_allocation = 0;
    fail_adapter = 1;
    assert(mcp23017_init() == NULL);
    assert(!allocations && !references && !registered);
    fail_adapter = 0;
    for (address = 0x20; address <= 0x27; address++) {
        fail_address = address;
        assert(mcp23017_init() == NULL);
        assert(!allocations && !references && !registered);
    }
    fail_address = -1;
    m = mcp23017_init();
    assert(m && registered == 8 && references == 1 && allocations == 1);
    mcp23017_free(m);
    assert(!allocations && !references && !registered);
    return 0;
}
"""


class DriverTests(unittest.TestCase):
    def test_client_api_and_cleanup_on_old_and_new_kernels(self):
        compiler = shutil.which("cc")
        if compiler is None:
            self.skipTest("C compiler is not available")
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            linux = directory / "linux"
            linux.mkdir()
            for name in ("i2c.h", "err.h", "kernel.h", "slab.h",
                         "version.h", "types.h"):
                (linux / name).write_text("")
            source = directory / "test.c"
            source.write_text(
                STUBS + '\n#include "' + str(ROOT / "joypi/src/mcp23017.c")
                + '"\n' + HARNESS
            )
            for version in ((4, 19, 0), (5, 2, 0), (5, 10, 103)):
                with self.subTest(version=version):
                    code = (version[0] << 16) + (version[1] << 8) + version[2]
                    executable = directory / "test"
                    subprocess.run(
                        [compiler, "-std=gnu89", "-Wall", "-Wextra", "-Werror",
                         f"-DLINUX_VERSION_CODE={code}", "-I", str(directory),
                         str(source), "-o", str(executable)],
                        check=True, capture_output=True, text=True,
                    )
                    subprocess.run(
                        [str(executable)], check=True, capture_output=True, text=True
                    )


if __name__ == "__main__":
    unittest.main()
