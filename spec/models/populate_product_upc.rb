require 'rails_helper'

RSpec.describe PopulateProductUpc do
  describe '#perform' do
    let(:current_user) { create(:user) }
    let(:product) { create(:shopbop_product) }
    let(:selected) { create(:shopbop_product_suggestion, brand: product.brand) }
    let!(:product_suggestion) { create(:product_suggestion, product: product, suggested: selected) }
    subject { described_class.new(product.id) }

    context 'when there no enough `found` selects for populate' do
      it 'shouldnt populate product with upc' do
        expect { subject.perform }.to_not(change{product.upc})
      end

      it 'shouldnt create product_upc entry' do
        expect { subject.perform }.to(change{ProductUpc.count}.by(0))
      end
    end

    context 'when there is enough `found` selects for populate' do
      before do
        create(:product_select, product: product, selected: selected, selected_percentage: product_suggestion.percentage,
          decision: :found, user_id: current_user.id)
        ProductSuggestion.create(product_id: 1, suggested_id: selected.id)
      end

      it 'should populate product with upc' do
        expect { subject.perform }.to(change{product.reload.upc}.from(nil).to(selected.upc))
      end

      it 'should change match for product' do
        expect { subject.perform }.to(change{product.reload.match}.from(true).to(false))
      end

      it 'should delete suggestions for product' do
        expect { subject.perform }.to(change{
            ProductSuggestion.where(product_id: product.id).size}.from(1).to(0))
      end

      it 'should delete suggestions with same upc' do
        expect { subject.perform }.to(change{
            ProductSuggestion.where(suggested_id: Product.where(upc: selected.upc)
                                                    .pluck(:id)).size
          }.from(2).to(0))
      end

      it 'should create product_upc entry' do
        expect { subject.perform }.to(change{ProductUpc.count}.by(1))
      end

      it 'should create product_upc entry with correct fields' do
        subject.perform
        entry = ProductUpc.last
        expect(entry.product_id).to eq(product.id)
        expect(entry.upc).to eq(selected.upc)
      end
    end

    context 'when trying to populate product which already has upc' do
      pending
    end

    context 'when trying to populate product which has associated product_upc entry' do
      pending
    end
  end
end
