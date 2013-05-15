% ParameterDropdownSelector (COSIVINA toolbox)
%   Control that creates a dropdown menu with an accompanying text field in
%   the GUI. The menu allows to change the values of one or more parameters
%   between a number of presets.
% 
% Constructor call:
% ParameterDropdownSelector(controlLabel, elementLabels, ...
%   parameterNames, dropdownValues, dropdownLabels, ...
%   initialSelection, toolTip, position)
% 
% Arguments:
% controlLabel - label of the control displayed in the text field next to
%   the dropdown menu
% elementLabels - string or cell array of strings specifying the
%   labels of elements connected to this control
% parameterNames - string or cell array of strings specifying the names of
%   the element parameters controlled by this slider; arguments
%   elementLabels and parameterNames must have the same size, with each
%   pair of entries fully specifying one controlled parameter
% dropdownValues - a numerical array or a cell array of numerical arrays
%   specifying the parameter values associated with each menu entry; if the
%   control is connected to a single element parameter, this argument
%   should be an array with one valid parameter value for each item in the
%   dropdown menu; if multiple parameters are connected, it should be a
%   cell array of such arrays
% dropdownLabels - cell array of strings specifying the menu items in the
%   dropdown menu (optional, if not specified the dropdownValues for the
%   first connected parameter are used as labels)
% initialSelection - integer specifying the initial selection in the 
%   dropdown menu (optional, default is 1)
% tooltip - tooltip displayed when hovering over the control with the mouse
%   (optional)
% position - position of the control in the GUI figure window in relative
%   coordinates (optional, is overwritten when specifying a grid position
%   in the GUI’s addControl function)
%
% Examples:
% h = ParameterDropdownSelector('p_sA', 'stimulus A', 'position', ...
%   [25, 50, 75], {'left', 'center', 'right'}, 2, ...
%   'position of stimulus A');
% h = ParameterDropdownSelector('d_s', {'stimulus A', 'stimulus B'},...
%   {'position', 'position'}, {[40, 45, 48], [60, 55, 52]}, ... 
%   {'far', 'close', 'very close'}, 1, 'distance between stimuli A and B');


classdef ParameterDropdownSelector < Control
  properties
    controlLabel
    elementLabels
    parameterNames
    dropdownValues
    dropdownLabels
    nEntries
    toolTip
    
    simulatorHandle
    nParameters
    dropdownHandle
    captionHandle
    
    relCaptionWidth = 0.2; % size of the caption relative to slider
    relPaddingWidth = 0.025; % padding on both sides of the caption
    
    lastValue = 1;
  end
  
  
  methods
    % constructor
    function obj = ParameterDropdownSelector(controlLabel, elementLabels, parameterNames, dropdownValues, dropdownLabels, ...
        initialSelection, toolTip, position)
      obj.controlLabel = controlLabel;
      obj.elementLabels = elementLabels;
      obj.parameterNames = parameterNames;
      obj.dropdownValues = dropdownValues;
      if nargin >= 5
        obj.dropdownLabels = dropdownLabels;
      end
      if nargin >= 6 && ~isempty(toolTip)
        obj.toolTip = toolTip;
      else
        obj.toolTip = obj.controlLabel;
      end
      if nargin >= 7
        obj.lastValue = initialSelection;
      end
      if nargin >= 8
        obj.position = position;
      end
      
      % check consistency of arguments specifying the controlled elements and parameters
      if ~iscell(obj.elementLabels)
        obj.elementLabels = {obj.elementLabels};
      end
      if ~iscell(obj.parameterNames)
        obj.parameterNames = {obj.parameterNames};
      end
      obj.nParameters = length(obj.parameterNames);
      if ~iscell(obj.dropdownValues)
        obj.dropdownValues = {obj.dropdownValues};
      end
      
      if ~iscellstr(obj.elementLabels) || ~iscellstr(obj.parameterNames) ...
          || numel(obj.elementLabels) ~= obj.nParameters
        error('ParameterDropdownSelector:ParameterDropdownSelector:argumentMismatch', ...
          ['Arguments elementLabels and parameterNames must be strings or cell arrays of strings '...
          'with equal number of elements.']);
      end
      if numel(obj.dropdownValues) ~= obj.nParameters
        error('ParameterDropdownSelector:ParameterDropdownSelector:argumentMismatch', ...
          ['Number of vectors in argument dropdownValues must match number of parameters specified ' ...
          'in argument parameterNames.']);
      end
      
      % determine entries of dropdown menu, fill in labels if necessary
      obj.nEntries = numel(obj.dropdownValues{1});
      if isempty(obj.dropdownLabels)
        obj.dropdownLabels = cell(1, obj.nEntries);
        for i = 1 : obj.nEntries
          obj.dropdownLabels{i} = num2str(obj.dropdownValues{1}(i));
        end
      end
      
      % check consistency of dropdownValues vectors, reformat for use in
      % setElementParameters method
      tmpValues = cell(obj.nEntries, 1);
      tmpValues(:) = {cell(1, obj.nParameters)};
      for i = 1 : obj.nParameters
        if numel(obj.dropdownValues{i}) ~= obj.nEntries
          error('ParameterDropdownSelector:ParameterDropdownSelector:argumentMismatch', ...
            'If argument dropdownValues is a cell array, all entries must be of the same size.');
        end
        for j = 1 : obj.nEntries
          tmpValues{j}{i} = obj.dropdownValues{i}(j);
        end
      end
      obj.dropdownValues = tmpValues;
      
      % check consistency of dropdownValues with dropdownLabels
      if numel(obj.dropdownLabels) ~= obj.nEntries
        error('ParameterDropdownSelector:ParameterDropdownSelector:argumentMismatch', ...
          'Size of argument dropdownLabels must match size of each vector in argument dropdownValues.');
      end
    end
    
    
    % connect to simulator object
    function obj = connect(obj, simulatorHandle)
      obj.simulatorHandle = simulatorHandle;
      for i = 1 : obj.nParameters
        tmpElementHandle = simulatorHandle.getElement(obj.elementLabels{i});
        if isempty(tmpElementHandle) || ~tmpElementHandle.isParameter(obj.parameterNames{i})
          error('ParameterDropdownSelector:connect:invalidParameter', ...
            'No element ''%s'' with parameter ''%s'' in simulator object.', obj.elementLabels{i}, obj.parameterNames{i});
        end
        if tmpElementHandle.getParamChangeStatus(obj.parameterNames{i}) == ParameterStatus.Fixed
          error('ParameterDropdownSelector:connect:parameterFixed', ...
            'Parameter ''%s'' in element ''%s'' has change status ''Fixed'' and cannot be changed by a GUI control.', ...
            obj.parameterNames{i}, obj.elementLabels{i});
        end
      end
    end
    
    
    % initialize control object
    function obj = init(obj, figureHandle)
      captionPosition = [obj.position(1) + obj.relPaddingWidth * obj.position(3), obj.position(2), ...
        obj.position(3) * obj.relCaptionWidth, obj.position(4)];
      dropdownPosition = [obj.position(1) + (obj.relCaptionWidth + 2*obj.relPaddingWidth) * obj.position(3), ...
        obj.position(2), (1 - obj.relCaptionWidth - 2*obj.relPaddingWidth) * obj.position(3), obj.position(4)];
            
      obj.captionHandle = uicontrol('Parent', figureHandle, 'Style', 'text', 'Units', 'norm', ...
        'HorizontalAlignment', 'left', 'String', [obj.controlLabel], ...
        'Position', captionPosition, 'Tooltip', obj.toolTip, 'BackgroundColor', 'w');
      obj.dropdownHandle = uicontrol('Parent', figureHandle, 'Style', 'popupmenu', 'Units', 'norm', ...
        'Position', dropdownPosition, 'String', obj.dropdownLabels, 'ToolTip', obj.toolTip, 'Value', obj.lastValue);
    end
    
    
    % check control object and update simulator object if required
    function changed = check(obj)
      if get(obj.dropdownHandle, 'Value') ~= obj.lastValue
        changed = true;
        obj.lastValue = get(obj.dropdownHandle, 'Value');

        setElementParameters(obj.simulatorHandle, obj.elementLabels, obj.parameterNames, ...
          obj.dropdownValues{obj.lastValue});
      else
        changed = false;
      end
    end
    
    
    % update control object (e.g. after parameters have been changed in parameter panel)
    function obj = update(obj) % updates the control eleme
      % state of ParameterSwitchButton is not updated on external parameter change
    end

  end
end