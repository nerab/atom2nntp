class ArticlesController < ApplicationController
  # GET /articles/1
  # GET /articles/72157620344514245@Strobist_com
  # GET /articles/1.xml
  def show
    @article = Article.find_by_id(params[:id])

    if nil == @article
      @article = Article.find_by_message_id(params[:id])
    end

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @article }
    end
  end

  # def next
  #   root.children.reject{|sibling| sibling.id <= a.id}.sort{|a,b| a.id <=> b.id}.first
  # end
end
