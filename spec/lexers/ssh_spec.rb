# -*- coding: utf-8 -*- #
# frozen_string_literal: true

describe Rouge::Lexers::SSH do
  let(:subject) { Rouge::Lexers::SSH.new }
  include Support::Lexing

  it 'lexes a specification' do
    example = 'Host example
  Hostname www.example.com
  Port 1234
  Tunnel no'

    assert_tokens_equal example, ["Keyword",        "Host"],
                                 ["Text",           " example\n  "],
                                 ["Keyword",        "Hostname"],
                                 ["Text",           " www.example.com\n  "],
                                 ["Keyword",        "Port"],
                                 ["Text",           " "],
                                 ["Literal.Number", "1234"],
                                 ["Text",           "\n  "],
                                 ["Keyword",        "Tunnel"],
                                 ["Text",           " "],
                                 ["Name.Constant",  "no"]
  end
end
