import h5py as h5
import numpy as np

import argparse
import sys


parser = argparse.ArgumentParser(description="Use the results of statistical_analysis.py to process a target database.")
parser.add_argument("features",
                    nargs="*",
                    default=["spectrum",
                             "spectrum_flux",
                             "peak_heights",
                             "peak_locations"],
                    help="Names of feature datasets in database")
parser.add_argument("-t --trg", dest="trgDBFileName", metavar="targetDB", nargs="?", default="training.h5", help="Database to process")
parser.add_argument("-s --src", dest="srcDBFileName", metavar="sourceDB", nargs="?", default="SA.h5", help="Database containing feature moments")
parser.add_argument("-o --out", dest="outDBFileName", metavar="outDB", nargs="?", default="out.h5", help="Processed version of targetDB (will be created/truncated)")
args = parser.parse_args()

srcFile = h5.File(args.srcDBFileName, "r")
trgFile = h5.File(args.trgDBFileName, "r")
outFile = h5.File(args.outDBFileName, "w")
print("Whitening %s using data from %s. Writing to %s." % (args.trgDBFileName, args.srcDBFileName, args.outDBFileName))
print("")


for trgDataset in trgFile:
    sys.stdout.write("\033[F")
    sys.stdout.write("\033[K")
    print("Copying %s..." % trgDataset)

    trgFile.copy(trgDataset, outFile)

for feature in args.features:
    sys.stdout.write("\033[F")
    sys.stdout.write("\033[K")
    print("Processing %s..." % feature)

    srcDataset = srcFile[feature]
    outDataset = outFile[feature]


    means = srcDataset[0, :]
    variances = srcDataset[1, :]
    standardDeviations = np.sqrt(variances)

    # replace any 0 elements with 1, ensuring safety when dividing by standardDeviations.
    safeSD = np.where(standardDeviations == 0, np.ones(standardDeviations.shape), standardDeviations)

    # out = (trg - mean) / sd
    outDataset[:, :] = (outDataset[:, :] - np.tile(means, (outDataset.shape[0], 1))) / np.tile(safeSD, (outDataset.shape[0], 1))

print("DONE!")
