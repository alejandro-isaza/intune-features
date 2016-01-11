import h5py as h5
import numpy as np
import scipy.stats as stats

import argparse
import csv
import sys


parser = argparse.ArgumentParser(description="Extract mean, variance and skewness (first 3 moments) from a database of features")
parser.add_argument("features",
                    nargs="*",
                    default=["spectrum",
                             "spectrum_flux",
                             "peak_heights",
                             "peak_locations"],
                    help="Names of datasets to find moments of")
parser.add_argument("inDBFileName", metavar="inDatabase", nargs="?", default="training.h5", help="Database to perform analysis on")
parser.add_argument("outDBFileName", metavar="outDatabase", nargs="?", default="SA.h5", help="Database to write moments to (will be created/truncated)")
parser.add_argument("csvFileName", metavar="outTable", nargs="?", default="SA.csv", help="CSV to write moments to (will be created/truncated)")
args = parser.parse_args()

inDBFile = h5.File(args.inDBFileName, "r")
print("Performing SA on %s" % args.inDBFileName)

csvFile = open(args.csvFileName, "w")
csvWriter = csv.writer(csvFile)
outDBFile = h5.File(args.outDBFileName, "w")
print("Writing results to table: %s and HDF5: %s" % (args.csvFileName, args.outDBFileName))

print("------------------------------")
print("")

for feature in args.features:
    sys.stdout.write("\033[F")
    sys.stdout.write("\033[K")
    print("Processing %s..." % feature)

    inDataset = inDBFile[feature]
    table = inDataset[:, :]

    assert np.isfinite(table).all()

    means = np.mean(table, axis=0)
    variances = np.var(table, axis=0)
    skewnesses = stats.skew(table, axis=0)

    csvWriter.writerow([feature])
    csvWriter.writerow(["means"] + means.tolist())
    csvWriter.writerow(["variances"] + variances.tolist())
    csvWriter.writerow(["skewnesses"] + skewnesses.tolist())

    outDataset = outDBFile.create_dataset(feature, (3, inDataset.shape[1]))
    outDataset[0, :] = means
    outDataset[1, :] = variances
    outDataset[2, :] = skewnesses


print("DONE!")
