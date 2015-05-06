#!/bin/sh

ruby gif-to-ruby.rb <owl.gif >owl.rb &&
  ruby owl.rb
