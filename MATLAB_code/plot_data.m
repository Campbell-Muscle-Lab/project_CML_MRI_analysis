function plot_data

wtf = '../output/wall_data.xlsx';
cf = 'c:/ken/github/campbellmusclelab/projects/project_R403Q_mri_analysis/data/mapping/file_map.xlsx';
mf = '../data/mouse_sid/mouse_sid.xlsx';

symbols = {'o','s','^','v'};
cm = [1 0 0 ; 0 1 0 ; 0 0 1 ; 1 0 1];

w = readtable(wtf);
c = readtable(cf);
m = readtable(mf);

m = m(cellfun(@isempty, m.RepeatInstrument),:);

wn = w.Properties.VariableNames';
cn = c.Properties.VariableNames';
mn = m.Properties.VariableNames';


m = removevars(m, setdiff(mn, {'RecordID','Sex','Genotype'}));
mn = m.Properties.VariableNames';


d = innerjoin(w,c, 'LeftKeys', {'code'}, 'RightKeys', ...
    {'deidentified_code'});
dn = d.Properties.VariableNames';

d = innerjoin(d, m, 'LeftKeys', 'mouse_id', 'RightKeys', 'RecordID');
dn = d.Properties.VariableNames'

% Plot
us = unique(d.Sex);
ug = unique(d.Genotype);
um = unique(d.mouse_id);

figure(1);
sp = initialise_publication_quality_figure( ...
        'no_of_panels_high', 1, ...
        'no_of_panels_wide', 1, ...
        'top_margin', 0.5, ...
        'right_margin', 3.5, ...
        'x_to_y_axes_ratio', 1);
hold on;    

for i = 1: numel(um)
    vi = find(d.mouse_id == um(i));
    
    ms = d.Sex{vi(1)};
    mg = d.Genotype{vi(1)};
    
    if (strcmp(ms, us{1}))
        if (strcmp(mg, ug{1}))
            ind=1
        else
            ind=2
        end
    else
        if (strcmp(mg, ug{1}))
            ind=3
        else
            ind=4
        end
    end
    h(ind) = plot(NaN,NaN, symbols{ind}, 'Color',cm(ind,:));
    labels{ind} = sprintf('%s %s', ms, mg)


    [~, si] = sort(d.scan_number(vi));
    
    plot(d.scan_number(vi(si)), d.septal_thickness_mean(vi(si)), ...
            [symbols{ind} '-'], ...
            'Color', cm(ind,:));
  
end

ylim([0 10]);
ylabel('Septal thickness (pixels)');
xlabel('Scan number');

legendflex(h, labels, 'anchor', {'n','s'}, 'nrow', 2, ...
    'buffer', [0 20]);


figure(2);
sp = initialise_publication_quality_figure( ...
        'no_of_panels_high', 1, ...
        'no_of_panels_wide', 1, ...
        'top_margin', 0.5, ...
        'right_margin', 3.5, ...
        'x_to_y_axes_ratio', 1)
subplot(sp(1));
hold on;    


for i = 1 : numel(us)
    for j = 1 : numel(ug)
        c = 2*(i-1) + j;
        for k = 1 : 5
            vi = find(strcmp(d.Sex, us{i}) & ...
                        strcmp(d.Genotype, ug{j}) & ...
                        d.scan_number == k);
            s = summary_stats(d.septal_thickness_mean(vi));
            x(k) = k;
            y(k) = s.mean;
            ye(k) = s.sem;
            n(k) = s.n;
        end
        
        errorbar(x+(c*0.05), y, ye, [symbols{c}], 'Color', cm(c,:));
        for k = 1 : 5
            text(x(k) + (c*0.05+0.15), y(k), ...
                sprintf('n=%i',n(k)), ...
                'Color', cm(c,:));
        end
    end
end

ylim([5 10]);
ylabel('Septal thickness (pixels)');
xlabel('Scan number');

a = gca;

legendflex(h, labels, 'ref', a, 'anchor', {'n','s'}, 'nrow', 2, ...
    'buffer', [0 20]);




    
    