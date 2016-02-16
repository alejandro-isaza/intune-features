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
                             "peak_locations",
                             "features_polyphony_values",
                             "features_length",
                             "sequence_length",
                             "event_offset"],
                    help="Names of datasets to find moments of")
parser.add_argument("inDBFileName", metavar="inDatabase", nargs="?", default="training.h5", help="Database to perform analysis on")
parser.add_argument("outDBFileName", metavar="outDatabase", nargs="?", default="SA.h5", help="Database to write moments to (will be created/truncated)")
parser.add_argument("csvFileName", metavar="outTable", nargs="?", default="SA.csv", help="CSV to write moments to (will be created/truncated)")
parser.add_argument("--no-error-check", dest="no_error_check", action="store_true", default=False, help="Do not perform error checks")
parser.add_argument("--no-stat-analysis", dest="no_stat_analysis", action="store_true", default=False, help="Do not perform statistical analysis")
args = parser.parse_args()

inDBFile = h5.File(args.inDBFileName, "r")
print("Performing SA on %s" % args.inDBFileName)

if not args.no_stat_analysis:
    csvFile = open(args.csvFileName, "w")
    csvWriter = csv.writer(csvFile)
    outDBFile = h5.File(args.outDBFileName, "w")
    print("Writing results to table: %s and HDF5: %s" % (args.csvFileName, args.outDBFileName))

    print("------------------------------")
    print("")

    for feature in args.features:
        print("Processing %s..." % feature)

        inDataset = inDBFile[feature]
        if len(inDataset.shape) == 3:
            table = inDataset[:, :, :].reshape((inDataset.shape[0] * inDataset.shape[1], inDataset.shape[2]))
        elif len(inDataset.shape) == 2:
            table = inDataset[:, :].reshape(inDataset.shape[0] * inDataset.shape[1], 1)
        else:
            table = inDataset[:].reshape((inDataset.size, 1))

        assert np.isfinite(table).all()

        maxes = np.amax(table, axis=0)
        mins = np.amin(table, axis=0)
        means = np.mean(table, axis=0)
        variances = np.var(table, axis=0)
        skewnesses = stats.skew(table, axis=0)

        csvWriter.writerow([feature])
        csvWriter.writerow(["means"] + means.tolist())
        csvWriter.writerow(["variances"] + variances.tolist())
        csvWriter.writerow(["skewnesses"] + skewnesses.tolist())
        csvWriter.writerow(["maxes"] + maxes.tolist())
        csvWriter.writerow(["mins"] + mins.tolist())

        outDataset = outDBFile.create_dataset(feature, (5, table.shape[1]))
        outDataset[0, :] = means
        outDataset[1, :] = variances
        outDataset[2, :] = skewnesses
        outDataset[3, :] = maxes
        outDataset[4, :] = mins

        print("     MAXES:", maxes)
        print("     MINS:", mins)
        print("     MEANS:", means)
        print("     VARIANCES:", variances)


if not args.no_error_check:
    error_datasets = [
                      ("features_polyphony_values", 10),
                      ("event_offset", (44 * 1024) - 1),
                      ("sequence_length", 20),
                      ("features_length", 43),
                      ]
    for (dataset, max_limit) in error_datasets:
        print("SEARCHING %s FOR ERRORS" % dataset)
        inDataset = inDBFile[dataset]

        if len(inDataset.shape) == 2:
            table = inDataset[:, :].reshape(inDataset.shape[0] * inDataset.shape[1])
            divisor = inDataset.shape[1]
        else:
            table = inDataset[:].reshape((inDataset.size))
            divisor = 1

        condition_table = table > max_limit
        if condition_table.any():
            for i, element in enumerate(condition_table):
                if element:
                    val = table[i]
                    file_id = inDBFile["file_id"][i // divisor]
                    file = inDBFile["file_list"][file_id]
                    offset = inDBFile["offset"][i // divisor]
                    print("      FOUND: Value %f in %s at %d" % (val, file, offset))


print("DONE!")
