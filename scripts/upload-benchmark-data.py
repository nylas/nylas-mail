import os
import re
import sys
import subprocess

from dateutil.parser import parse as parse_datestr
from glob import glob

import gspread

from oauth2client.service_account import ServiceAccountCredentials

scope = ['https://spreadsheets.google.com/feeds']


def usage():
    print "./scripts/upload-benchmark-data.py <datadir>"


def anymean(filename):
    output = subprocess.check_output(['./scripts/toolbox/any_mean.py', filename])
    if output == '':
        return 0.0, 0.0

    # e.g. 'Synced Messages: 77.00 +-0.00'
    synced_messages, confidence_interval = re.match('^Synced Messages: ([0-9.]+) (\+-[0-9.]+)$', output).groups()
    return synced_messages, confidence_interval


def update_spreadsheet(datadir):
    credentials = ServiceAccountCredentials.from_json_keyfile_name('client_secret.json', scope)
    gc = gspread.authorize(credentials)
    worksheet = gc.open("Nylas Mail Benchmarks").sheet1

    filenames = []
    for filename in glob('{datadir}/*-results.txt'.format(datadir=datadir)):
        gitsha = re.match('^(.*)-results.txt$', os.path.basename(filename)).groups(0)[0]
        formatted_datetime = subprocess.check_output(['git', 'show', '-s', '--format=%ci', gitsha])
        parsed_datetime = parse_datestr(formatted_datetime)
        filenames.append((filename, gitsha, parsed_datetime))

    new_data = []
    for filename, gitsha, parsed_datetime in sorted(filenames, key=lambda t: t[2]):
        synced_messages, confidence_interval = anymean(filename)
        row = (parsed_datetime.strftime("%Y-%m-%d %H:%M:%S"), gitsha, synced_messages, confidence_interval)
        new_data.append(row)
        print row

    # TODO: might want to use the batch upload api in order to not run into rate-limits
    for i, new_row in enumerate(new_data):
        row_num = i+2
        existing_row = worksheet.range('A{row_num}:D{row_num}'.format(row_num=row_num))
        for j, cell in enumerate(existing_row):
            col_num = j+1
            cell.value = new_row[j]
            print "updating cell {row_num}:{col_num} with {val}".format(row_num=row_num, col_num=col_num, val=cell.value)
        worksheet.update_cells(existing_row)


def main():
    if len(sys.argv) != 2:
        usage()
        return 1

    datadir = sys.argv[1]
    update_spreadsheet(datadir)
    return 0

if __name__ == '__main__':
    sys.exit(main())
