function pull_data

% Variables
frame_data_file_string = '../data/manual_check/output_frames.xlsx';
mri_data_folder = '../data/deidentified_scans';

analysis_image_folder = '../output/analysis_images';
output_file_string = '../output/wall_data.xlsx';

% Code
d = readtable(frame_data_file_string);
dn = d.Properties.VariableNames'

progress_bar(0);
for i = 1 : numel(d.deid_code)
    
    progress_bar(i / numel(d.deid_code));
    
    data_folder = fullfile(mri_data_folder, d.deid_code{i});
    dicom_file = findfiles('dcm', data_folder, 0);
    
    im_data = dicomread(dicom_file{1});
    im_data = squeeze(im_data(:,:,1,d.ed_frame(i)));
    
    lv_data = identify_lv(im_data);
    
    wall_data = deduce_wall_thickness(im_data, ...
        [lv_data.Centroid_1 lv_data.Centroid_2], ...
        'figure_summary_file_string', ...
            fullfile(analysis_image_folder, d.deid_code{i}), ...
        'figure_summary_title', d.deid_code{i});
   
    out.code{i} = d.deid_code{i};
    out.septal_thickness(i) = wall_data.septal_thickness;
    
end

out = columnize_structure(out);
out = struct2table(out);
try
    delete(output_file_string);
end
writetable(out, output_file_string);