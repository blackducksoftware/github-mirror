class GHTorrent::EtagHelper
  def initialize(command, url)
    @ght = command.ght
    @url = url
  end

  def request(media_type)
    result = verify_etag_and_get_response(media_type) if first_page? && cacheable_endpoint?
    result ||= @ght.do_request(@url, media_type)
    store_etag_in_db(result) if cacheable_endpoint? && cacheable_page?(result.meta['link'])
    result
  end

  private

  def verify_etag_and_get_response(media_type)
    etag_data, etag_response = etag_data_and_response(media_type)
    return unless etag_response
    log_etag_usage(etag_data) if etag_response.status[0] == '304'
    # Since the current api call is for first page, do not return etag response for backloaded api.
    etag_response if modified?(etag_response) && etag_data[:page_no] == 1
  end

  def cacheable_endpoint?
    patterns = [%r{/user/(?:search|email)}, %r{/orgs/[^/]+/members},
                %r{/users/[^/]+/orgs}, %r{/compare/.+\.\.\.},
                %r{/commits/[^/]+$}, %r{/commits\?sha=}]
    patterns.none? { |pattern| @url =~ pattern }
  end

  def etag_data_and_response(media_type)
    etag_data = @ght.db[:etags].first(base_url: base_url)
    return unless etag_data
    etag_response = get_etag_response(etag_data, media_type)
    [etag_data, etag_response]
  end

  def modified?(response)
    response && response.status[0] == '200'
  end

  def first_page?
    current_page_no.to_i == 1
  end

  def current_page_no
    @current_page_no ||= extract_page_no(@url) || 1
  end

  def extract_page_no(string)
    string.slice(/\bpage=(\d+)/, 1)
  end

  def store_etag_in_db(result)
    params = { base_url: base_url, page_no: current_page_no,
               etag: result.meta['etag'] }

    record = @ght.db[:etags].first(base_url: base_url)
    if record
      @ght.db[:etags].where(base_url: base_url).update(params)
    else
      @ght.db[:etags].insert(params)
    end
  end

  def cacheable_page?(link_headers)
    front_loaded? ? first_page? : last_page?(link_headers)
  end

  # The Link header rel="last" will NOT be present on the last page.
  def last_page?(link_headers)
    link_headers !~ /\; rel="last"/
  end

  def base_url
    return @base_url if @base_url
    base_url = @url.slice(/^[^\?]+/).chomp('/')
    param = '?state=closed' if @url =~ /state=closed/
    @base_url = base_url + param.to_s
  end

  def get_etag_response(etag_data, media_type)
    new_url = modify_page_in_url(etag_data[:page_no])
    @ght.do_request(new_url, media_type, 'If-None-Match' => etag_data[:etag])
  rescue OpenURI::HTTPError => e # 304 response raises an error.
    response = e.io
    raise e unless response.status.first == '304'
    response
  end

  def front_loaded?
    base_url =~ %r{/repos/[^/]+/[^/]+/\w+/?$} && base_url !~ %r{/stargazers/?$}
  end

  def modify_page_in_url(page_no)
    page_regexp = /\bpage=\d*/
    if @url.match(page_regexp)
      @url.sub(page_regexp, "page=#{page_no}")
    else
      appender = @url =~ /\?/ ? '&' : '?'
      @url + "#{appender}page=#{page_no}"
    end
  end

  def log_etag_usage(etag_data)
    @ght.db[:etags].where(base_url: etag_data[:base_url])
                   .update(used_count: etag_data[:used_count] + 1)
  end
end
