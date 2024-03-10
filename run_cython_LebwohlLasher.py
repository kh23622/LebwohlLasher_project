import sys
from cython_LebwohlLasher import main

ITERATIONS = 50
SIZE = 50
TEMPERATURE = 0.5
PLOTFLAG = 0

main("LebwohlLasher", ITERATIONS, SIZE, TEMPERATURE, PLOTFLAG)
