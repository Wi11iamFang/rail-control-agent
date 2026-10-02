% Launch the interactive DMI prototype from this workspace.
% Run this script instead of adding the outputs folder to the MATLAB path.

thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
cd(thisDir);

oldOutputDir = fullfile(thisDir, 'outputs');
if contains(path, oldOutputDir)
    rmpath(oldOutputDir);
end

clear classes
rehash

disp('Loading RemoteDMIApp from:')
which RemoteDMIApp

app = RemoteDMIApp;
