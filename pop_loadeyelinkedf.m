% pop_loadeyelinkedf() - Import Eyelink edf file and return EEGLAB EEG
%                        structure
%
% Usage:
%   >> [ EEG, com ] = pop_loadeyelinkedf; % pop-up window mode
%   >> [ EEG, com ] = pop_loadeyelinkedf( 'key1', value1, 'key2', ...
%                                         value2, 'keyn', valuen);
%
% Optional inputs:
%   'pathname'  - path to file
%   'filename'  - name of Eyelink edf file
%   'chans'     - cell array channels to import {default { 'pa', 'gx', 'gy' }}
%   'types'     - cell array event types to import {default
%                 { 'MESSAGEEVENT', 'STARTBLINK ', 'ENDBLINK', 'STARTSACC',
%                 'ENDSACC' }}
%
% Outputs:
%   EEG       - EEGLAB EEG structure
%   com       - history string
%
% Note:
%   Requires edfmex binary. Download for your platform from (SR Research
%   support forum account required):
%   https://www.sr-support.com/thread-28.html
%
% Author: Andreas Widmann, 2021

% Copyright (C) 2021 Andreas Widmann, University of Leipzig, widmann@uni-leipzig.de
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

function [ EEG, com ] = pop_loadeyelinkedf( varargin )

com = '';
EEG = [];

if nargin < 2
    Arg.filename = [];
else
    Arg = cell2struct(varargin(2:2:end), varargin(1:2:end - 1), 2);
end

if ~isfield( Arg, 'filename' ) || isempty( Arg.filename )
    [ Arg.filename, Arg.pathname ] = uigetfile2( { '*.edf' }, 'Select Eyelink edf-file - pop_loadeyelinkedf()');
    if Arg.filename == 0, return; end
end

% Defaults
if ~isfield( Arg, 'chans' ) || isempty( Arg.chans )
    Arg.chans = { 'pa', 'gx', 'gy' };
end
if ~isfield( Arg, 'types' ) || isempty( Arg.types )
    Arg.types = { 'MESSAGEEVENT', 'STARTBLINK ', 'ENDBLINK', 'STARTSACC', 'ENDSACC' };
end
eyeLabelArray = {{''}, {'l', 'r'}};

Raw = edfmex(fullfile(Arg.pathname, Arg.filename));

% if length(Raw.RECORDINGS) > 2
%     error('Import of multiple recordings not yet implemented.')
% end

try
    EEG = eeg_emptyset;
catch
    EEG.data = [];
    EEG.chanlocs = [];
    EEG.event = [];
end

EEG.FEVENT = Raw.FEVENT;
EEG.RECORDINGS = Raw.RECORDINGS;

EEG.srate = double(Raw.RECORDINGS(1).sample_rate);
% samplingPeriod = 1000 / EEG.srate;
% timeZero = double(Raw.RECORDINGS(1).time);

% % Prefix all fields in FEVENT with el_
% tempArray = fieldnames(Raw.FEVENT);
% for iField = 1:length(tempArray)
%     [Raw.FEVENT.(['el_' tempArray{iField}])] = Raw.FEVENT.(tempArray{iField});
% end
% Raw.FEVENT = rmfield(Raw.FEVENT, tempArray);

for iChan = 1:length(Arg.chans)
    
    nEyes = size(Raw.FSAMPLE.(Arg.chans{iChan}), 1);
    
    EEG.data = [EEG.data; double(Raw.FSAMPLE.(Arg.chans{iChan}))];

    for iEye = 1:nEyes
        EEG.chanlocs(end + 1).labels = [Arg.chans{iChan} eyeLabelArray{nEyes}{iEye}];
    end

end

% EEG.event = Raw.FEVENT; % Copy event structure

% Filter event structure
if isfield(Arg, 'types') && ~isempty(Arg.types)
    evtArray = false(1, length(Raw.FEVENT));

    for iType = 1:length(Arg.types)
        evtArray = evtArray | strcmp(Arg.types{iType}, {Raw.FEVENT.codestring});
    end

else
    evtArray = true(1, length(Raw.FEVENT));
end
evtArray = num2cell(find(evtArray));
[EEG.event(1:length(evtArray)).urFEVENT] = deal(evtArray{:});

timeArray = double(Raw.FSAMPLE.time);

for iEvt = 1:length(EEG.event)

    if strcmp(Raw.FEVENT(EEG.event(iEvt).urFEVENT).codestring, 'MESSAGEEVENT')
        EEG.event(iEvt).type = Raw.FEVENT(EEG.event(iEvt).urFEVENT).message;
    else
        EEG.event(iEvt).type = Raw.FEVENT(EEG.event(iEvt).urFEVENT).codestring;
    end

    % Shift ENDSAMPLES and ENDEVENTS events by one sample (to avoid empty event latencies)
    if any( strcmp( Raw.FEVENT(EEG.event(iEvt).urFEVENT).codestring, { 'ENDSAMPLES', 'ENDEVENTS' } ) )
        Raw.FEVENT(EEG.event(iEvt).urFEVENT).sttime = Raw.FEVENT(EEG.event(iEvt).urFEVENT).sttime - 1;
        Raw.FEVENT(EEG.event(iEvt).urFEVENT).entime = Raw.FEVENT(EEG.event(iEvt).urFEVENT).entime - 1;
    end
        
    if strncmp(Raw.FEVENT(EEG.event(iEvt).urFEVENT).codestring, 'END', 3)
%         EEG.event(iEvt).latency = (double(EEG.event(iEvt).el_entime) - timeZero) / samplingPeriod + 1;
        % Test alternative version supporting multiple recordings
        EEG.event(iEvt).latency = find(timeArray >= double(Raw.FEVENT(EEG.event(iEvt).urFEVENT).entime), 1);
%         if temp ~= EEG.event(iEvt).latency, error('Two versions computing event latency do mot match!'), end
    else
%         EEG.event(iEvt).latency = (double(EEG.event(iEvt).el_sttime) - timeZero) / samplingPeriod + 1;
        % Test alternative version supporting multiple recordings
        EEG.event(iEvt).latency = find(timeArray >= double(Raw.FEVENT(EEG.event(iEvt).urFEVENT).sttime), 1);
%         if temp ~= EEG.event(iEvt).latency, error('Two versions computing event latency do mot match!'), end
    end
    
    EEG.event(iEvt).eye = double(Raw.FEVENT(EEG.event(iEvt).urFEVENT).eye) + 1;

end

% Boundary events
if length(Raw.RECORDINGS) > 2

    for iRec = 1:length( Raw.RECORDINGS )
        if Raw.RECORDINGS( iRec ).state == 1
            
            EEG.event( end + 1 ).type = 'boundary';
            EEG.event( end ).latency = find(timeArray >= double(Raw.RECORDINGS( iRec ).time), 1);
            EEG.event( end ).eye = 1;

            EEG.event( end + 1 ).type = 'STARTREC';
            EEG.event( end ).latency = find(timeArray >= double(Raw.RECORDINGS( iRec ).time), 1);
            EEG.event( end ).eye = 1;

        elseif Raw.RECORDINGS( iRec ).state == 0
            
            EEG.event( end + 1 ).type = 'ENDREC';
            EEG.event( end ).latency = find(timeArray <= double(Raw.RECORDINGS( iRec ).time), 1, 'last');
            EEG.event( end ).eye = 1;

        end

    end
    
end

% Remove events with empty latency
cleanEvt = cellfun( @isempty, { EEG.event.latency } );
if any( cleanEvt )
    warning( 'Events with empty event latency field detected and removed.' )
    { EEG.event( cleanEvt ).type } %#ok<NOPRT>
    EEG.event( cleanEvt ) = [];
end

EEG.nbchan = size(EEG.data, 1);
EEG.trials = 1;
EEG.pnts = size(EEG.data, 2);
EEG.xmin = 0;
EEG.xmax = (EEG.pnts - 1) / EEG.srate;

if any( [ EEG.event.eye ] == 3 )
    warning( 'Event with eye==3/both. Check data.' )
end

try
%     EEG = eeg_checkset( EEG );
    EEG = eeg_checkset( EEG, 'eventconsistency' );
catch
end

end
