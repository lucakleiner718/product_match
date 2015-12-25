require 'rails_helper'

RSpec.describe MatchProcessor do
  describe '#process' do
    let(:current_user) { create(:user) }
    let(:product) { create(:shopbop_product) }
    let(:selected) { create(:shopbop_product_suggestion, brand: product.brand) }
    let!(:product_suggestion) { create(:product_suggestion, product: product, suggested: selected) }
    subject { described_class.new(current_user.id, product.id, decision, selected.id) }

    context 'when clicked `found`' do
      let(:decision) { :found }

      it 'should select product' do
        expect { subject.process }.to(change{
            ProductSelect.where(user_id: current_user.id, product_id: product.id, selected_id: selected.id,
              decision: decision).count
          }.by(1))
      end
    end

    context 'when clicked `nothing`' do
      let(:decision) { :nothing }

      it 'should select product' do
        expect { subject.process }.to(change{
            ProductSelect.where(user_id: current_user.id, product_id: product.id, decision: decision).count
          }.by(1))
      end
    end

    context 'when clicked `no color`' do
      let(:decision) { :'no-color' }

      it 'should select product' do
        expect { subject.process }.to(change{
            ProductSelect.where(user_id: current_user.id, product_id: product.id, decision: decision).count
          }.by(1))
      end
    end

    context 'when clicked `no size`' do
      let(:decision) { :'no-size' }

      it 'should select product' do
        expect { subject.process }.to(change{
            ProductSelect.where(user_id: current_user.id, product_id: product.id, decision: decision).count
          }.by(1))
      end
    end
  end
end
