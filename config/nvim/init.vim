call map(sort(split(globpath(&runtimepath, 'config/*.vim'))), {->[execute('exec "so" v:val')]})
