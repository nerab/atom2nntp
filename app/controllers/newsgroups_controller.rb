class NewsgroupsController < ApplicationController
  # GET /newsgroups
  # GET /newsgroups.xml
  def index
    @newsgroups = Newsgroup.find(:all)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @newsgroups }
    end
  end

  # GET /newsgroups/1
  # GET /newsgroups/1.xml
  def show
    @newsgroup = Newsgroup.find(params[:id])
    @grouped_by_from = @newsgroup.articles.group_by(&:from).sort{|x, y| x.size <=> y.size}
    @top_authors = Article.find_by_sql("select *, count(id) as a_count from articles where newsgroup_id = " <<  @newsgroup.id.to_s << " group by \"from\" order by a_count desc LIMIT 5")
    @top_authors.reject!{|a| a.from == "unknown"}
    @max_per_author = @top_authors.max{|a,b| a.a_count <=> b.a_count}.a_count.to_i
    
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @newsgroup }
    end
  end

  # GET /newsgroups/new
  # GET /newsgroups/new.xml
  def new
    @newsgroup = Newsgroup.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @newsgroup }
    end
  end

  # GET /newsgroups/1/edit
  def edit
    @newsgroup = Newsgroup.find(params[:id])
  end

  # POST /newsgroups
  # POST /newsgroups.xml
  def create
    MiddleMan.worker(:fetch_feed_worker).async_fetch_feed(:arg => params[:newsgroup][:feed_url]) 
    
    respond_to do |format|
        flash[:notice] = 'Creation of newsgroup was successfully launched. Reload this page to see the update.'
        format.html { redirect_to(newsgroups_url) }
        format.xml  { head :ok }
    end
  end

  # PUT /newsgroups/1
  # PUT /newsgroups/1.xml
  def update
    @newsgroup = Newsgroup.find(params[:id])

    respond_to do |format|
      if @newsgroup.update_attributes(params[:newsgroup])
        flash[:notice] = 'Newsgroup was successfully updated.'
        format.html { redirect_to(@newsgroup) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @newsgroup.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /newsgroups/1
  # DELETE /newsgroups/1.xml
  def destroy
    @newsgroup = Newsgroup.find(params[:id])
    @newsgroup.destroy

    respond_to do |format|
      format.html { redirect_to(newsgroups_url) }
      format.xml  { head :ok }
    end
  end
end
