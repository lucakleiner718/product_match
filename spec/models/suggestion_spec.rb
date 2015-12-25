require 'rails_helper'

RSpec.describe Suggestion do
  describe '#build' do
    let(:brand) { create(:brand, name: 'Vince') }
    let(:product) { create(:shopbop_product) }
    subject { described_class.new(product.id) }

    context 'when product is present' do
      before do
        create(:shopbop_product_suggestion)
      end

      it 'should generate suggestions' do
        expect { subject.build }.to(change{ ProductSuggestion.count }.by(1))
      end
    end

    # context 'when have similar products to original' do
    #   before do
    #     create(:shopbop_product, size: 'XL', upc: '822508892312', brand_id: product.brand_id)
    #     create(:shopbop_product, size: 'S', upc: '822508892325', brand_id: product.brand_id)
    #
    #     create(:shopbop_product_suggestion, brand_id: product.brand_id)
    #   end
    #
    #   it 'should find similar products' do
    #     expect { subject.build }.to(change{ ProductSuggestion.count }.by(1))
    #   end
    # end
  end
end
