from distutils.core import setup
from Cython.Build import cythonize

setup(name="cython_LebwohlLasher",
      ext_modules=cythonize("cython_LebwohlLasher.pyx"))
