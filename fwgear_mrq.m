function fwgear_mrq(config_file_path, output_dir)

%{
    0. Parse the configuration file for inputs and config.
    1. Initilize FW SDK
    2. Find and download the input data
    3. Set up the mrQ structure with params and input data
    4. RUN
    5. Cleanup and preserve outputs (archive) - promote QA data to output.

%}


%% Set path variables

% Path where the outputs will be stored.
if ~exist('output_dir', 'var')
    output_dir = fullfile(fileparts(config_file_path), 'output');
end

if ~exist(output_dir, 'dir')
    disp('Creating output directory');
    mkdir(output_dir);
end

% Path where the nifti data are downloaded (dataDir in mrQ lingo)
raw_dir = fullfile(fileparts(config_file_path), 'raw_data');
if ~exist(raw_dir, 'dir')
    disp('Creating NIfTI directory');
    mkdir(raw_dir);
end


%% 0. Read configuration file

if ~exist(config_file_path, 'file')
    error('%s does not exist!', (config_file_path));
else
    raw_config = jsondecode(fileread(config_file_path));
end


%% 1. Initialize the FW SDK

fw = flywheel.Client(raw_config.inputs.api_key.key);


%% 2.0 Get the analysis, session, and acquisitions

% Here we use the destination id (which is for the analysis) to grab the
% session id for the session which we're operating upon.

analysis   = fw.getAnalysis(raw_config.destination.id);
session_id = analysis.parent.id;
session    = fw.getSession(session_id);
subject    = fw.getSubject(session.subject.id);

% Find all the acquisitions in this session
acquisitions = session.acquisitions();


%% Make subject-specific output directory

subject_output_dir = fullfile(output_dir, [subject.code, '_', session.label, '-mrQ_Output']);
mkdir(subject_output_dir);


%% 2.1 Iterate over all of the acquisitions and use the regex for each type of
% scan to find the appropriate acquisitions

% SPGR and IR data arrays (** later we keep track of which data are used as input)
spgr_data = {};
ir_data   = {};

% Regular expressions for acq labels (from config file)
spgr_regex = raw_config.config.spgr_regex;
ir_regex   = raw_config.config.ir_regex;

% Here we grab the session that was provided by the user as the session
% having additional data that should be used for this analysis. We then append
% to the list of acquisitions the acquisitions from the "session_split"
% session.
if isfield(raw_config.config, 'session_split') && ~isempty(raw_config.config.session_split)
    fprintf('Looking for additonal acquisitions in: %s\n', (raw_config.config.session_split));
    s2 = fw.lookup(raw_config.config.session_split);
    s2acquisitions = fw.getSessionAcquisitions(s2.id);
    for jj = 1:numel(s2acquisitions)
        acquisitions{end+1} = s2acquisitions{jj};
    end
end

% For each acquisition, if the label matched one of the regexs, then add
% it to the appropriate data array (SPGR, or IR).
fprintf('Looking for matching acquisitions:\n')

for ii = 1:numel(acquisitions)

    spgr_regex_index = regexpi(acquisitions{ii}.label,spgr_regex);
    if ~isempty(spgr_regex_index)
        fprintf('\t%s\n', acquisitions{ii}.label)
        spgr_data{end+1} = acquisitions{ii};
    end

    ir_regex_index = regexpi(acquisitions{ii}.label,ir_regex);
    if ~isempty(ir_regex_index)
        fprintf('\t%s\n', acquisitions{ii}.label)
        ir_data{end+1} = acquisitions{ii};
    end

end


%% 2.2

% For each type of acquisition, download the nifti file to the raw data
% directory (raw_dir)
input_acquisitions = horzcat(spgr_data, ir_data);
fprintf('***\nFound %d matching acquisitions.\n***\n', (numel(input_acquisitions)));
fprintf('Downloading raw NIfTI data from Flywheel:\n')

input_files = cell(1, numel(input_acquisitions));
for ii = 1:numel(input_acquisitions)
    acquisition = fw.get(input_acquisitions{ii}.id);
    for ff = 1:numel(acquisition.files)
        if strcmpi(acquisition.files{ff}.type, 'nifti')

            % Grab the info to build the resolve path
            proj_label = fw.get(acquisition.parents.project).label;
            session_label = fw.get(acquisition.parents.session).label;
            resolvepath = [ acquisition.parents.group, '/', ...
                        proj_label, '/', ...
                        session_label, '/', ...
                        acquisition.label, '/', ...
                        acquisition.files{ff}.name ];
            fprintf('  %s...\n', resolvepath);

            % Download the file
            acquisition.files{ff}.download(fullfile(raw_dir, acquisition.files{ff}.name));

            % Build input file struct for analysis_info output
            input_files{ii} = struct;
            input_files{ii}.name = acquisition.files{ff}.name;
            input_files{ii}.acquisition = acquisition.id;
            input_files{ii}.path = resolvepath;
        end
    end
end


%% 2.3

% Initiate a struct thatwill have all the data that we used as input - we
% do this because we use the SDK to get the input data, thus we don't have
% another record of the data that were used.
analysis_info = struct;
analysis_info.input_files = input_files;


%% 3. Set up the mrQ_run

config = raw_config.config;

if isfield(raw_config.inputs, 'b1fieldmap')
    B1file = raw_config.inputs.b1fieldmap.location.path;
else
    B1file = [];
end

if isfield(raw_config.inputs, 'reference_image')
    reference_image = raw_config.inputs.reference_image.location.path;
    config.autoacpc = 0;
else
    reference_image = [];
end

disp('Configuration Parameters:');
disp(config);


% RUN IT
mrQ_run(raw_dir, subject_output_dir, [], [], B1file, {  'wl', config.lw_model, ...
                                                        'refim', reference_image, ...
                                                        'autoacpc', config.autoacpc, ...
                                                        'lsq', config.lsq_model, ...
                                                        'pdfit_method', config.pdfit_method, ...
                                                        'testr1_bm', config.r1_bm, ...
                                                        'polydeg', config.polydeg, ...
                                                        'fieldstrength', config.fieldstrength ...
                                                        });


%% 4. Post-Run processes


% 0 Add log and params to analysis_info
analysis_info.fitlog = load(fullfile(subject_output_dir, 'fitLogB1.mat'));
analysis_info.params = load(fullfile(subject_output_dir, 'mrQ_params.mat'));
analysis_info.config = config;


% 0.1 Check for success
if isfield(analysis_info.params.mrQ, 'T1w_files')
    if isdir(analysis_info.params.mrQ.T1w_files)
        disp('Run completed successfully!');
    end
else
    error('mrQ does not appear to have finished correctly!');
end


% 1. Add info to analysis info, or to a file
% analysis.updateInfo(jsonencode(analysis_info)); # This does not work as
% there are many "null" fields in the output, which the API rejects, thus
% we write to a file an move on with our lives.
disp('Generating metadata file from analysis info...');
jsonwrite(fullfile(output_dir,  [ subject.code '_' session.label '-analysis_info.json']), analysis_info);


% 2. Copy png images and T1w.nii.gz to the top level
copyfile(fullfile(subject_output_dir, 'OutPutFiles_1', 'summary.jpg'), fullfile(output_dir, [ subject.code '_' session.label '-summary.jpg' ]));
copyfile(fullfile(subject_output_dir, 'OutPutFiles_1', 'summary_BiasMaps.jpg'), fullfile(output_dir, [ subject.code '_' session.label '-summary_BiasMaps.jpg' ]), 'f');
copyfile(fullfile(subject_output_dir, 'OutPutFiles_1', 'T1w', 'T1w.nii.gz'), fullfile(output_dir, [ subject.code '_' session.label '-T1.nii.gz']), 'f');


% 3. Fix links and zip outputs
disp('Compressing outputs...');
status = system(['fix_links.sh ' output_dir]);
disp(status);
zip(fullfile(output_dir, [subject.code, '_', session.label, '-mrQ_Output.zip']), subject_output_dir);


% 4. Clean up...
disp('Cleaning up...');
rmdir(subject_output_dir, 's');
disp('Done!!!');



end
