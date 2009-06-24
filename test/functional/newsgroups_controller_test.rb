require 'test_helper'

class NewsgroupsControllerTest < ActionController::TestCase
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:newsgroups)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end

  def test_should_create_newsgroup
    assert_difference('Newsgroup.count') do
      post :create, :newsgroup => { }
    end

    assert_redirected_to newsgroup_path(assigns(:newsgroup))
  end

  def test_should_show_newsgroup
    get :show, :id => newsgroups(:one).id
    assert_response :success
  end

  def test_should_get_edit
    get :edit, :id => newsgroups(:one).id
    assert_response :success
  end

  def test_should_update_newsgroup
    put :update, :id => newsgroups(:one).id, :newsgroup => { }
    assert_redirected_to newsgroup_path(assigns(:newsgroup))
  end

  def test_should_destroy_newsgroup
    assert_difference('Newsgroup.count', -1) do
      delete :destroy, :id => newsgroups(:one).id
    end

    assert_redirected_to newsgroups_path
  end
end
