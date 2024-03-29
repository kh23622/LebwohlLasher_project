"""
Basic Python Lebwohl-Lasher code.  Based on the paper 
P.A. Lebwohl and G. Lasher, Phys. Rev. A, 6, 426-429 (1972).
This version in 2D.

Run at the command line by typing:

python LebwohlLasher.py <ITERATIONS> <SIZE> <TEMPERATURE> <PLOTFLAG>

where:
  ITERATIONS = number of Monte Carlo steps, where 1MCS is when each cell
      has attempted a change once on average (i.e. SIZE*SIZE attempts)
  SIZE = side length of square lattice
  TEMPERATURE = reduced temperature in range 0.0 - 2.0.
  PLOTFLAG = 0 for no plot, 1 for energy plot and 2 for angle plot.
  
The initial configuration is set at random. The boundaries
are periodic throughout the simulation.  During the
time-stepping, an array containing two domains is used; these
domains alternate between old data and new data.

SH 16-Oct-23
"""

import sys
import time
import datetime
import numpy as np
import matplotlib.pyplot as plt
import matplotlib as mpl
cimport numpy as np
import cython.cimports.libc.math as cmath
from cython cimport double
from libc.stdlib cimport rand, RAND_MAX
from math import cos, exp
#=======================================================================
def initdat(int nmax, double Ts):
    
    """
    Arguments:
      nmax (int) = size of lattice to create (nmax,nmax).
    Description:
      Function to create and initialise the main data array that holds
      the lattice.  Will return a square lattice (size nmax x nmax)
      initialised with random orientations in the range [0,2pi].
    Returns:
      arr (float[nmax,nmax]) = array to hold lattice.
    """
    cdef:
        np.ndarray[np.float64_t, ndim=2] arr
    arr = np.random.random_sample((nmax,nmax))*2.0*np.pi
    return arr
#=======================================================================
cdef void plotdat(np.ndarray[np.float64_t, ndim=2] arr, int pflag, int nmax):
    """
    Arguments:
	  arr (float[nmax,nmax]) = array that contains lattice data;
	  pflag (int) = parameter to control plotting;
      nmax (int) = side length of square lattice.
    Description:
      Function to make a pretty plot of the data array.  Makes use of the
      quiver plot style in matplotlib.  Use pflag to control style:
        pflag = 0 for no plot (for scripted operation);
        pflag = 1 for energy plot;
        pflag = 2 for angles plot;
        pflag = 3 for black plot.
	  The angles plot uses a cyclic color map representing the range from
	  0 to pi.  The energy plot is normalised to the energy range of the
	  current frame.
	Returns:
      NULL
    """
    print("Data type of arr:", arr.dtype)

    if pflag==0:
        return 
    cdef np.ndarray[np.float64_t, ndim=2] u = np.cos(arr)
    cdef np.ndarray[np.float64_t, ndim=2] v = np.sin(arr)
    cdef np.ndarray[np.float64_t, ndim=1] x = np.arange(nmax)
    cdef np.ndarray[np.float64_t, ndim=1] y = np.arange(nmax)
    cdef np.ndarray[np.float64_t, ndim=2] cols = np.zeros((nmax,nmax))
    if pflag==1: # colour the arrows according to energy
        mpl.rc('image', cmap='rainbow')
        for i in range(nmax):
            for j in range(nmax):
                cols[i,j] = one_energy(arr,i,j,nmax)
        norm = plt.Normalize(cols.min(), cols.max())
    elif pflag==2: # colour the arrows according to angle
        mpl.rc('image', cmap='hsv')
        cols = arr%np.pi
        norm = plt.Normalize(vmin=0, vmax=np.pi)
    else:
        mpl.rc('image', cmap='gist_gray')
        cols = np.zeros_like(arr)
        norm = plt.Normalize(vmin=0, vmax=1)

    quiveropts = dict(headlength=0,pivot='middle',headwidth=1,scale=1.1*nmax)
    fig, ax = plt.subplots()
    q = ax.quiver(x, y, u, v, cols,norm=norm, **quiveropts)
    ax.set_aspect('equal')
    plt.show()
#=======================================================================
cdef void savedat(np.ndarray[np.float64_t, ndim=2] lattice_np,
                  int nsteps, double temp, double runtime,
                  np.ndarray[np.float64_t, ndim=1] ratio,
                  np.ndarray[np.float64_t, ndim=1] energy,
                  np.ndarray[np.float64_t, ndim=1] order,
                  int nmax):
    """
    Arguments:
        lattice_np (np.ndarray[np.float64_t, ndim=2]): array that contains lattice data;
        nsteps (int): number of Monte Carlo steps (MCS) performed;
        temp (float): reduced temperature (range 0 to 2);
        runtime (float): runtime of the simulation;
        ratio (np.ndarray[np.float64_t, ndim=1]): array of acceptance ratios per MCS;
        energy (np.ndarray[np.float64_t, ndim=1]): array of reduced energies per MCS;
        order (np.ndarray[np.float64_t, ndim=1]): array of order parameters per MCS;
        nmax (int): side length of square lattice to simulated.
    Description:
        Function to save the energy, order, and acceptance ratio
        per Monte Carlo step to text file. Also saves run data in the
        header. Filenames are generated automatically based on
        date and time at the beginning of execution.
    Returns:
        NULL
    """

    # Create filename based on current date and time.
    current_datetime = datetime.datetime.now().strftime("%a-%d-%b-%Y-at-%I-%M-%S%p")
    filename = "LL-Output-{:s}.txt".format(current_datetime)
    FileOut = open(filename,"w")
    # Write a header with run parameters
    print("#=====================================================",file=FileOut)
    print("# File created:        {:s}".format(current_datetime),file=FileOut)
    print("# Size of lattice:     {:d}x{:d}".format(nmax,nmax),file=FileOut)
    print("# Number of MC steps:  {:d}".format(nsteps),file=FileOut)
    print("# Reduced temperature: {:5.3f}".format(temp),file=FileOut)
    print("# Run time (s):        {:8.6f}".format(runtime),file=FileOut)
    print("#=====================================================",file=FileOut)
    print("# MC step:  Ratio:     Energy:   Order:",file=FileOut)
    print("#=====================================================",file=FileOut)
    # Write the columns of data
    for i in range(nsteps+1):
        print(" {:05d} {:6.4f} {:12.4f} {:6.4f} ".format(i,ratio[i],energy[i],order[i]),file=FileOut)
    FileOut.close()
#=======================================================================
cdef double one_energy(double[:, :] arr, int ix, int iy, int nmax):
    """
    Arguments:
        arr (float[:, :]) = array that contains lattice data;
        ix (int) = x lattice coordinate of cell;
        iy (int) = y lattice coordinate of cell;
        nmax (int) = side length of square lattice.
    Description:
        Function that computes the energy of a single cell of the
        lattice taking into account periodic boundaries.  Working with
        reduced energy (U/epsilon), equivalent to setting epsilon=1 in
        equation (1) in the project notes.
    Returns:
        en (float) = reduced energy of cell.
    """
    cdef double en = 0.0
    cdef int ixp = (ix + 1) % nmax
    cdef int ixm = (ix - 1) % nmax
    cdef int iyp = (iy + 1) % nmax
    cdef int iym = (iy - 1) % nmax

    cdef double ang = arr[ix, iy] - arr[ixp, iy]
    en += 0.5 * (1.0 - 3.0 * cos(ang) ** 2)
    ang = arr[ix, iy] - arr[ixm, iy]
    en += 0.5 * (1.0 - 3.0 * cos(ang) ** 2)
    ang = arr[ix, iy] - arr[ix, iyp]
    en += 0.5 * (1.0 - 3.0 * cos(ang) ** 2)
    ang = arr[ix, iy] - arr[ix, iym]
    en += 0.5 * (1.0 - 3.0 * cos(ang) ** 2)
    return en

#=======================================================================
cpdef double all_energy(double[:, :] arr, int nmax):
    """
    Arguments:
        arr (double[:, :]) : array that contains lattice data;
        nmax (int) : side length of square lattice.
    Description:
        Function to compute the energy of the entire lattice. Output
        is in reduced units (U/epsilon).
    Returns:
        enall (double) : reduced energy of lattice.
    """
    # Declare C variables
    cdef int i, j
    cdef double enall = 0.0
    
    # Compute energy using a typed memory view
    for i in range(nmax):
        for j in range(nmax):
            enall += one_energy(arr, i, j, nmax)
    
    return enall
#=======================================================================
cdef double get_order(double[:, ::1] arr, int nmax):
    cdef int nmax_c = nmax
    cdef double[:, ::1] Qab = np.zeros((3, 3))
    cdef double[:, ::1] delta = np.eye(3)
    cdef double[:, :, ::1] lab = np.zeros((3, nmax_c, nmax_c))
    cdef int a, b, i, j

    # Precompute np.cos and np.sin values to avoid repeated function calls
    cdef double[:, :] cos_arr = np.cos(arr)
    cdef double[:, :] sin_arr = np.sin(arr)

    for i in range(nmax_c):
        for j in range(nmax_c):
            lab[0, i, j] = cos_arr[i, j]
            lab[1, i, j] = sin_arr[i, j]

    for a in range(3):
        for b in range(3):
            for i in range(nmax_c):
                for j in range(nmax_c):
                    Qab[a, b] += 3 * lab[a, i, j] * lab[b, i, j] - delta[a, b]

    cdef double tmp = 2 * nmax * nmax
    for a in range(3):
        for b in range(3):
            Qab[a, b] /= tmp

    cdef double[::1] eigenvalues = np.linalg.eigvalsh(Qab)
    return eigenvalues[2]  # Return the maximum eigenvalue

#=======================================================================
cdef double MC_step(double[:, ::1] arr, double Ts, int nmax):
    """
    Arguments:
        arr (float(nmax,nmax)) = array that contains lattice data;
        Ts (float) = reduced temperature (range 0 to 2);
        nmax (int) = side length of square lattice.
    Description:
        Function to perform one MC step, which consists of an average
        of 1 attempted change per lattice site.  Working with reduced
        temperature Ts = kT/epsilon.  Function returns the acceptance
        ratio for information.  This is the fraction of attempted changes
        that are successful.  Generally aim to keep this around 0.5 for
        efficient simulation.
    Returns:
        accept/(nmax**2) (float) = acceptance ratio for current MCS.
    """
    cdef double scale = 0.1 + Ts
    cdef int accept = 0

    cdef np.ndarray[np.int64_t, ndim=2] xran
    cdef np.ndarray[np.int64_t, ndim=2] yran
    cdef np.ndarray[double, ndim=2] aran
    cdef np.ndarray[double, ndim=2] random_comparison
    cdef np.ndarray[double, ndim=2] point_picked

    cdef int i, j, ix, iy
    cdef float ang, en0, en1, boltz
    cdef np.ndarray[np.int64_t, ndim=2] xran
    cdef np.ndarray[np.int64_t, ndim=2] yran
    cdef np.ndarray[double, ndim=2] aran

    for i in range(nmax):
        for j in range(nmax):
            xran = np.random.randint(0,high=nmax, size=(nmax,nmax))
            yran = np.random.randint(0,high=nmax, size=(nmax,nmax))
            aran = np.random.normal(scale=scale, size=(nmax,nmax))

            ix = xran[i,j]
            iy = yran[i,j]
            ang = aran[i,j]
            en0 = one_energy(arr,ix,iy,nmax)
            arr[ix,iy] += ang
            en1 = one_energy(arr,ix,iy,nmax)
            if en1<=en0:
                accept += 1
        else:
            # Now apply the Monte Carlo test - compare
            # exp( -(E_new - E_old) / T* ) >= rand(0,1)
            boltz = cmath.exp( -(en1 - en0) / Ts )

            if boltz >= np.random.uniform(0.0,1.0):
                accept += 1
            else:
                arr[ix,iy] -= ang
return accept/(nmax*nmax)
#=======================================================================
def main(program: str, nsteps: int, nmax: int, temp: float, pflag: int):  
    """
    Arguments:
        program (string) = the name of the program;
        nsteps (int) = number of Monte Carlo steps (MCS) to perform;
        nmax (int) = side length of square lattice to simulate;
        temp (float) = reduced temperature (range 0 to 2);
        pflag (int) = a flag to control plotting.
    Description:
        This is the main function running the Lebwohl-Lasher simulation.
    Returns:
        NULL
    """
    # Create and initialise lattice
    lattice_np = initdat(nmax, temp)
    # Plot initial frame of lattice
    plotdat(lattice_np, pflag, nmax)
    # Create arrays to store energy, acceptance ratio and order parameter
    energy = np.zeros(nsteps+1, dtype=np.float64)
    ratio = np.zeros(nsteps+1, dtype=np.float64)
    order = np.zeros(nsteps+1, dtype=np.float64)  # Initialize as float64
    # Set initial values in arrays
    energy[0] = all_energy(lattice_np, nmax)
    ratio[0] = 0.5  # ideal value
    order[0] = get_order(lattice_np, nmax)

    # Begin doing and timing some MC steps.
    cdef int it

    initial = time.time()
    for it in range(1, nsteps+1):
        ratio[it] = MC_step(lattice_np, temp, nmax)
        energy[it] = all_energy(lattice_np, nmax)
        order[it] = get_order(lattice_np, nmax)
    final = time.time()
    runtime = final-initial
    # Final outputs
    print("{}: Size: {:d}, Steps: {:d}, T*: {:5.3f}: Order: {:5.3f}, Time: {:8.6f} s".format(program, nmax, nsteps, temp, order[nsteps-1], runtime))
    # Plot final frame of lattice and generate output file
    savedat(lattice_np, nsteps, temp, runtime, ratio, energy, order, nmax)
    plotdat(lattice_np, pflag, nmax)

#=======================================================================
# Main part of program, getting command line arguments and calling
# main simulation function.
#
if __name__ == '__main__':
    if int(len(sys.argv)) == 5:
        PROGNAME = sys.argv[0]
        ITERATIONS = int(sys.argv[1])
        SIZE = int(sys.argv[2])
        TEMPERATURE = float(sys.argv[3])
        PLOTFLAG = int(sys.argv[4])
        main(PROGNAME, ITERATIONS, SIZE, TEMPERATURE, PLOTFLAG)
    else:
        print("Usage: python {} <ITERATIONS> <SIZE> <TEMPERATURE> <PLOTFLAG>".format(sys.argv[0]))
#=======================================================================
