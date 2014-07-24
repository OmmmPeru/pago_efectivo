require 'gyoku'
require 'builder'
require 'net/http'

module PagoEfectivo

  SCHEMA_TYPES = {
    'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
    'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
    'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/'
  }

  def initialize
    @api_server = 'https://pre.pagoefectivo.pe'
  end

  def create_markup(body)
    xml_markup = Builder::XmlMarkup.new(indent: 2)
    xml_markup.instruct! :xml
    xml_markup << body.to_s
    xml_markup
  end

  def request_signature(text, private_key)
    path = '/PagoEfectivoWSCrypto/WSCrypto.asmx'
    hash = { signer: { plain_text: text, private_key: private_key }}
    options = { key_converter: :camelcase, key_to_convert: 'signer'}
    attributes = {"soap:Envelope" => SCHEMA_TYPES}
    xml_body = Gyoku.xml({"soap:Envelope" => {"soap:Body" => hash},
                          :attributes! => attributes}, options)

    xml = create_markup(xml_body)

    server = @api_server + path
    request = Net::HTTP::Post.new(server)
    request.set_form_data(xml)
    response = Net::HTTP.start(server.hostname, server.port) do |http|
      http.use_ssl = true
      JSON.parse(http.request(request))
    end
    reponse
  end

  def generate_cip
  end

  def consult_cip
  end

  def delete_cip
  end

  def update_cip
  end
end
