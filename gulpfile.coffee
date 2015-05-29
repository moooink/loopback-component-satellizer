coffee  = require 'gulp-coffee'
gulp    = require 'gulp'
gutil   = require 'gulp-util'

gulp.task 'build', ->
  gulp.src './source/*.coffee'
  .pipe coffee bare: true
  .on 'error', gutil.log
  .pipe gulp.dest './lib/'
