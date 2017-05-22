# -*- coding: utf-8 -*- #

describe Rouge::Lexers::Coq do
  let(:subject) { Rouge::Lexers::Coq.new }

  describe 'guessing' do
    include Support::Guessing

    it 'guesses by mimetype' do
      assert_guess :mimetype => 'text/x-coq'
    end
  end
end
