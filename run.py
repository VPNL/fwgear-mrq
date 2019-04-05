#!/usr/bin/env python

###############################################################################
# MAIN

if __name__ == '__main__':

    import os
    import logging
    import shutil
    import argparse
    import subprocess
    import datetime

    logging.basicConfig()
    log = logging.getLogger('QMR')
    log.setLevel(getattr(logging, 'DEBUG'))
    logging.getLogger('QMR').setLevel(logging.INFO)
    log.info('  start %s' % datetime.datetime.utcnow())

    os.environ['FLYWHEEL_SDK_SKIP_VERSION_CHECK'] = '1'

    ap = argparse.ArgumentParser()
    ap.add_argument('--config_file',
                    type=str,
                    dest="config_file",
                    default='/flywheel/v0/config.json',
                    help='Full path to the input json config file.')

    ap.add_argument('--output_dir',
                    type=str,
                    dest="output_dir",
                    default='/flywheel/v0/output',
                    help='Directory in which to save the results.')

    args = ap.parse_args()

    # RUN MATLAB CODE
    matlab_binary = '/usr/local/bin/run_fLocGearRun.sh'
    matlab_library = '/opt/mcr/v93'

    with open('/dockerenv.json', 'r') as f:
            environ = json.load(f)

    run_command = [matlab_binary, matlab_library, args.config_file, args.output_dir]
    status = subprocess.check_call(run_command, evn=environ)

    # EXIT
    if status == 0:
        log.info('Success!')
    os.sys.exit(status)
