% This script should be run on Matlab 2017b, GLNXA64.
%
% EXAMPLE USAGE
%       /software/matlab/r2017b/bin/matlab -nodesktop -r mrq_build

% Check that we are running a compatible version
if (isempty(strfind(version, '9.3.0'))) || (isempty(strfind(computer, 'GLNXA64')))
    error('You must compile this function using R2017b (9.3.0.713579) 64-bit (glnxa64). You are using %s, %s', version, computer);
end

disp(mfilename('fullpath'));
compileDir = fileparts(mfilename('fullpath'));
if ~strcmpi(pwd, compileDir)
    disp('You must run this code from %s', compileDir);
end

% Check for spm8
spm_path = fileparts(which('spm'));
if isempty(spm_path)
  error('Please add the SPM8 to your path prior to building this code!')
end

% Download the source code
disp('Cloning source code...');
system('mkdir source_code')
system('git clone https://github.com/vistalab/vistasoft source_code/vistasoft');
system('git clone https://github.com/gllmflndn/JSONio.git source_code/JSONio');
system('git clone https://github.com/xiangruili/dicm2nii.git source_code/dcm2nii');
%system('git clone https://github.com/mezera/mrQ.git source_code/mrQ');
system('git clone -b poly https://github.com/vistalab/mrQ.git source_code/mrQ');
system('git clone https://github.com/kendrickkay/knkutils.git source_code/knkutils');
system('wget https://github.com/flywheel-io/core/releases/download/5.0.4/flywheel-matlab-sdk-5.0.4.zip -O source_code/flywheel-matlab-sdk.zip && unzip source_code/flywheel-matlab-sdk.zip -d source_code/ && rm -f source_code/flywheel-matlab-sdk.zip');


% Set paths
disp('Adding paths to build scope...');
restoredefaultpath;
addpath(genpath(spm_path));
addpath(genpath(fullfile(pwd, 'source_code')));
javaaddpath(fullfile(pwd, 'source_code', 'flywheel-sdk', 'api', 'rest-client.jar'));

% Compile
disp('Running compile code...');
mcc -v -R -nodisplay -m ../fwgear_mrq.m -a ./source_code/flywheel-sdk -a ./source_code/vistasoft/mrDiffusion -a ./source_code/mrQ/SEIR/T1FitNLSPR.m -d ./bin

% Clean up
disp('Cleaning up...')
try
    rmdir(fullfile(pwd, 'source_code'), 's');
catch
    disp('Could not remove source_code directory');
end

disp('Done!');
exit
