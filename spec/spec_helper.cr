require "spec"
require "../src/po_parser"

PO_FILE = File.expand_path("fixtures/complete_file.po", __DIR__)
NON_ASCII_FILE = File.expand_path("fixtures/non_ascii_file.po", __DIR__)

PO_HEADER = File.read(File.expand_path("fixtures/header.po", __DIR__))
PO_SIMPLE_MESSAGE = File.read(File.expand_path("fixtures/simple_entry.po", __DIR__), "UTF-8")
PO_COMPLEX_MESSAGE = File.read(File.expand_path("fixtures/complex_entry.po", __DIR__), "UTF-8")
