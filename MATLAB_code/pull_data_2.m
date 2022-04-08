function pull_data

% Variables
mri_data_folder = '../data/deidentified_scans';

ed_frame_file = '../output/ed_frame.xlsx';
ed_r_squared_threshold = 0.9;


analysis_image_folder = '../output/analysis_images';
output_file_string = '../output/wall_data.xlsx';

% Code
dicom_files = findfiles('dcm', mri_data_folder, 1);

[path_names, file_names] = fileparts(dicom_files);
for i = 1 : numel(path_names)
    temp = strsplit(path_names{i}, filesep);
    d.deid_code{i} = temp{end};
end
% Turn d into a table
d = columnize_structure(d);
d = struct2table(d);

% Load edv data
ed = readtable(ed_frame_file);
edn = ed.Properties.VariableNames'

% Inner join codes and frames
d = innerjoin(d, ed, 'LeftKeys', 'deid_code', 'RightKeys', 'code');
% Filter
d(d.r_squared < ed_r_squared_threshold, :) = []

progress_bar(0);
for i = 1 : numel(d.deid_code)
    
    progress_bar(i / numel(d.deid_code));
    
    data_folder = fullfile(mri_data_folder, d.deid_code{i});
    dicom_file = findfiles('dcm', data_folder, 0);
    
    im_data = dicomread(dicom_file{1});
    im_data = squeeze(im_data(:,:,1, d.ed_frame(i)));
    
    lv_data = identify_lv(im_data)
    
    wall_data = deduce_wall_thickness(im_data, ...
        [lv_data.Centroid_1 lv_data.Centroid_2], ...
        'figure_summary_file_string', ...
            fullfile(analysis_image_folder, d.deid_code{i}), ...
        'figure_summary_title', sprintf('%s frame %i', ...
            d.deid_code{i}, d.ed_frame(i)));
    
    out.lv_area(i) = lv_data.Area;
    out.lv_eccentricity(i) = lv_data.Eccentricity;
    out.lv_solidity(i) = lv_data.Solidity;   
    out.code{i} = d.deid_code{i};
    out.septal_thickness_mean(i) = wall_data.septal_thickness_mean;
    out.septal_thickness_n(i) = wall_data.septal_thickness_n;
    out.septal_thickness_sem(i) = wall_data.septal_thickness_sem;
    
end

out = columnize_structure(out);
out = struct2table(out);
try
    delete(output_file_string);
end
writetable(out, output_file_string);