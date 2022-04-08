function test_lv
% Function 

% Variables
data_dir = '../data/deidentified_scans';
output_file_string = '../output/a.xlsx';
output_image_folder = '../output/a';


% Code
dicom_files = findfiles('dcm', data_dir, 1);

% Cycle through files
d_counter = 1;
progress_bar(0);
for file_counter = 1 : numel(dicom_files)
    progress_bar(file_counter / numel(dicom_files));
    
    % Load dicom and deduce number of frames
    dic = dicomread(dicom_files{file_counter});
    [~, ~, no_of_frames] = size(dic);

    % Get the deid code
    dir_parts = strsplit(dicom_files{file_counter}, filesep);
    deid_code = dir_parts{end-1};
    im_file_name = dir_parts{end};
    
    % Loop through frames
    for frame_counter = 1 : no_of_frames
        
        fig_file_string = fullfile(output_image_folder, ...
                            sprintf('%s_%s_%i', ...
                                deid_code, im_file_name, frame_counter));
        fig_title = sprintf('%s_%s Frame %i', ...
                        deid_code, im_file_name, frame_counter);
        
        im_frame = squeeze(dic(:,:,1,frame_counter));
                    
        im_data = identify_lv( ...
                    im_frame, ...
                    'figure_summary_file_string', fig_file_string, ...
                    'figure_summary_title', fig_title);
                
        % Store the data
        if (isstruct(im_data))
            d.deid_code{d_counter} = deid_code;
            d.im_file_name{d_counter} = im_file_name;
            d.frame_number(d_counter) = frame_counter;
            field_names = fieldnames(im_data);
            for i = 1 : numel(field_names)
                temp = im_data.(field_names{i});
                if (isnumeric(temp))
                    d.(field_names{i})(d_counter) = temp;
                else
                    d.(field_names{i}){d_counter} = temp;
                end
            end
            d_counter = d_counter + 1;
        end
    end
end

% Write data
try
    delete(output_file_string);
end
d = columnize_structure(d);
d = struct2table(d);
writetable(d, output_file_string);
