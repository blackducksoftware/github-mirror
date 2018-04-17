
FactoryGirl.define do
    
    factory :user, :class => OpenStruct   do
      skip_create
        login 'harrison'
        name  'george'
        email 'gh@gmail.com'
        transient do
            with_states []
            db_obj nil
        end

      after(:create) do | user, evaluator |
        byebug
        user.db_obj = evaluator.db_obj 
        hashed = build(:user).to_h
        user.db_obj[:users].insert(hashed)
      end
    end
  end