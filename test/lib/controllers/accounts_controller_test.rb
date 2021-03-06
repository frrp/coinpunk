require_relative '../../controller_config.rb'

describe IndexController do
  before do
    @controller = AccountsController
    Sinatra::Sessionography.session.clear
  end
  
  describe 'signup' do
    it 'redirects if already logged in' do
      Sinatra::Sessionography.session[:account_email] = 'test@example.com'
      get '/new'
      status.must_equal 302
      headers['Location'].must_match /\/dashboard$/
    end
    
    it 'loads for no session' do
      get '/new'
      status.must_equal 200
      body.must_match /new account/i
    end
  end

  describe 'signin' do
    it 'fails for missing login' do
      post '/signin', email: 'fail@example.com', password: 'lol'
      fail_signin
    end

    it 'fails for bad password' do
      @account = Fabricate :account
      post '/signin', email: @account.email, password: 'derp'
      fail_signin
    end

    it 'fails for no input' do
      post '/signin'
      fail_signin
    end

    it 'succeeds for valid input' do
      password = '1tw0rkz'
      @account = Fabricate :account, password: password
      post '/signin', email: @account.email, password: password
      headers['Location'].must_equal 'http://example.org/dashboard'
    end
    
    
    it 'works for temp account' do
      account = Fabricate :account, {password: 'loltest123', temporary_password: true}
      post '/signin', email: account.email, password: 'loltest123'
      headers['Location'].must_equal 'http://example.org/accounts/change_temporary_password'
      get '/change_temporary_password'
      body.must_match /change temporary password/i
      post '/change_temporary_password', password: 'bad'
      body.must_match /change temporary password.+password must be at least #{Account::MINIMUM_PASSWORD_LENGTH} characters/mi
      post '/change_temporary_password', password: 'this0nework$'
      status.must_equal 302
      headers['Location'].must_equal 'http://example.org/dashboard'
      Sinatra::Sessionography.session[:account_email].must_equal account.email
      Sinatra::Sessionography.session[:flash][:success].must_match /Temporary password changed/i
    end
  end

  describe 'account creation' do
    it 'fails for no input' do
      post '/create'
      status.must_equal 200
      body.must_match /There were some errors.+Valid email address is required.+Password must be/
    end

    it 'fails with invalid email' do
      post '/create', email: 'derplol'
      status.must_equal 200
      body.must_match /errors.+valid email/i
    end

    it 'fails with invalid password' do
      post '/create', 'email@example.com', password: 'sdd'
      status.must_equal 200
      body.must_match /errors.+Password must be at least #{Account::MINIMUM_PASSWORD_LENGTH} characters/i
    end

    it 'succeeds with valid info' do
      account_attributes = Fabricate.attributes_for :account

      stub_rpc 'getaccountaddress', [account_attributes[:email]], body: {result: SecureRandom.hex}

      post '/create', account_attributes
      status.must_equal 302
      headers['Location'].must_equal 'http://example.org/dashboard'
      Sinatra::Sessionography.session[:account_email].must_equal account_attributes[:email]
    end
  end
end

def fail_signin
  headers['Location'].must_equal 'http://example.org/'
  Sinatra::Sessionography.session[:account_email].must_be_nil
  Sinatra::Sessionography.session[:flash][:error].must_match /Invalid login/i
end