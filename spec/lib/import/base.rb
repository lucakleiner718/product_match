require 'rails_helper'

RSpec.describe Import::Base do
  subject { described_class.new }
  let(:check_upc_rule) { false }

  describe '.check_upc' do
    context 'when upc provided, ean is blank' do
      let(:item) { { upc: 884092914274 } }
      it 'should leave upc as is' do
        expect{ subject.check_upc(item, check_upc_rule) }.to_not change{ item }
      end
    end

    context 'when upc provided, ean provided' do
      let(:item) { { upc: 884092914274, ean: 884092721162 } }
      it 'should remove ean and leave upc as is' do
        expect{ subject.check_upc(item, check_upc_rule) }.to change{ item }.to({ upc: 884092914274 })
      end
    end

    context 'when upc blank, ean provided' do
      let(:item) { { upc: nil, ean: 884092721162 } }
      it 'should set upc as ean and delete ean' do
        expect{ subject.check_upc(item, check_upc_rule) }.to change{ item }.to({ upc: 884092721162 })
      end
    end
  end

end
