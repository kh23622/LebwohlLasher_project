The objective of this project is to evaluate various acceleration techniques, including Numpy vectorization, Numba, Cython, and OpenMPI, applied to the Lebwohl-Lasher model. The project aims to systematically simulate the model across different temperatures to determine the most effective optimization method. By analyzing the performance of each technique, the project identifies Cython as the most effective method, significantly improving code efficiency and speeding up the simulation of liquid crystal systems.

Here's a breakdown of the runtime improvements achieved by each optimization method in percentage:

Numpy Vectorization:
Version 1: 3.312s to 0.709s (Improvement: ~78.6%)
Final Version: 0.709s (Improvement: ~78.6%)

Numba:
Original: 3.000s to 0.420s (Improvement: ~86.7%)

Cython:
Initial: 3.007s to 0.297s (Improvement: ~90.1%)

OpenMPI:
No significant improvement observed.
