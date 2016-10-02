require 'pandoc-ruby'

class ManifestationController < ApplicationController
  before_filter :require_editor, only: [:edit, :update]
  def read
    @m = Manifestation.find(params[:id])
    @html = MultiMarkdown.new(@m.markdown.lines[1..-1].join("\n")).to_html.force_encoding('UTF-8')
    @tabclass = set_tab('works')
    @proof = Proof.new
  end
  def download
    @m = Manifestation.find(params[:id])
    filename = @m.safe_filename+'.'+params[:format]
    html = "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\"><html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"he\" lang=\"he\" dir=\"rtl\"><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" /></head><body dir='rtl' align='right'><div dir=\"rtl\" align=\"right\">"+MultiMarkdown.new(@m.markdown).to_html.force_encoding('UTF-8')+"\n\n<hr />"+I18n.t(:download_footer_html, url: url_for(action: :read, id: @m.id))+"</div></body></html>"
    case params[:format]
    when 'pdf'
      pdfname = HtmlFile.pdf_from_any_html(html)
      pdf = File.read(pdfname)
      send_data pdf, type: 'application/pdf', filename: filename
      File.delete(pdfname) # delete temporary generated PDF
    when 'doc'
      begin
        temp_file = Tempfile.new('tmp_doc_'+@m.id.to_s, 'tmp/')
        #temp_file.puts(PandocRuby.convert(html, from: :html, to: :odt).force_encoding('UTF-8'))
        temp_file.puts(PandocRuby.convert(html, from: :html, to: :docx).force_encoding('UTF-8'))
        #temp_file.puts(PandocRuby.convert(@m.markdown, from: :markdown, to: :docx).force_encoding('UTF-8'))
        temp_file.chmod(0644)
        send_file temp_file, type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', filename: filename
      ensure
        temp_file.close
      end
    when 'html'
      begin
        temp_file = Tempfile.new('tmp_html_'+@m.id.to_s, 'tmp/')
        temp_file.puts(html)
        temp_file.chmod(0644)
        send_file temp_file, type: 'text/html', filename: filename
      ensure
        temp_file.close
      end
    when 'txt'
      txt = html2txt(html)
      begin
        temp_file = Tempfile.new('tmp_txt_'+@m.id.to_s,'tmp/')
        temp_file.puts(txt)
        temp_file.chmod(0644)
        send_file temp_file, type: 'text/plain', filename: filename
      ensure
        temp_file.close
      end
    when 'epub'
      begin
        epubname = make_epub_from_single_html(html, @m)
        epub_data = File.read(epubname)
        send_data epub_data, type: 'application/epub+zip', filename: filename
        File.delete(epubname) # delete temporary generated EPUB
      end
    when 'mobi'
      begin
        # TODO: figure out how not to go through epub
        epubname = make_epub_from_single_html(html, @m)
        mobiname = epubname[epubname.rindex('/')+1..-6]+'.mobi'
        out = `kindlegen #{epubname} -c1 -o #{mobiname}`
        mobi_data = File.read(mobiname)
        send_data mobi_data, type: 'application/x-mobipocket-ebook', filename: filename
        File.delete(epubname) # delete temporary generated EPUB
        File.delete(mobiname) # delete temporary generated MOBI
      end
    else
      flash[:error] = t(:unrecognized_format)
      redirect_back fallback_location: {action: read, id: @m.id}
    end
  end
  def list
    # calculations
    @total = Manifestation.count
    # form input
    unless params[:commit].blank?
      session[:mft_q_params] = params # make prev. params accessible to view
    else
      session[:mft_q_params] = { title: '', author: '' }
    end

    # DB
    p = params[:path]
    if p.blank?
      @manifestations = Manifestation.page(params[:page]).order('title ASC')
    else
      @manifestations = Manifestation.where('path like ?', '%' + p + '%').page(params[:page]).order('title ASC')
    end
  end

  def show
    @m = Manifestation.find(params[:id])
    @e = @m.expressions[0] # TODO: generalize?
    @w = @e.works[0] # TODO: generalize!

  end

  def render_html
    @m = Manifestation.find(params[:id])
    @html = MultiMarkdown.new(@m.markdown).to_html.force_encoding('UTF-8')
  end

  def edit
  end

end
