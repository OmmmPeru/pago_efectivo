require 'savon'
require 'gyoku'
require 'nokogiri'

module PagoEfectivo
  class Client
    SCHEMA_TYPES = {
      'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
      'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
      'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/'
    }

    def initialize(options = {})
      if options[:env] == 'production'
        @api_server = 'https://pagoefectivo.pe'
      else
        @api_server = 'https://pre.2b.pagoefectivo.pe'
      end

      crypto_path = '/PagoEfectivoWSCrypto/WSCrypto.asmx?WSDL'
      cip_path = '/PagoEfectivoWSGeneralv2/service.asmx?WSDL'
      crypto_service = @api_server + crypto_path
      cip_service = @api_server + cip_path
      savon_opts = {}
      savon_opts[:proxy] = ENV['PROXY_URL'] if options[:proxy]
      savon_opts[:ssl_verify_mode] = none if options[:ssl] == false

      @crypto_client = Savon.client({ wsdl: crypto_service }.merge(savon_opts))
      @cip_client = Savon.client({ wsdl: cip_service }.merge(savon_opts))
    end

    def set_key type, path
      raise 'path to your key is not valid' unless File.exists?(path)
      if type == 'private'
        @private_key = File.open(path, 'rb') {|f| Base64.encode64(f.read)}
      elsif type == 'public'
        @public_key = File.open(path, 'rb') {|f| Base64.encode64(f.read)}
      end
    end

   def create_markup(body)
     xml_markup = Nokogiri.XML(body).to_xml
   end

    def signature(text)
      response = @crypto_client.call(:signer, message: {
                                  plain_text: text, private_key: @private_key
                                })
      response.to_hash[:signer_response][:signer_result]
    end

    def encrypt_text(text)
      response = @crypto_client.call(:encrypt_text, message: {
                                  plain_text: text, public_key: @public_key
                                })
      response.to_hash[:encrypt_text_response][:encrypt_text_result]
    end

    def unencrypt enc_text
      response = @crypto_client.call(:decrypt_text, message: {
                                  encrypt_text: enc_text, private_key: @private_key
                                })
      response.to_hash[:decrypt_text_response][:decrypt_text_result]
    end

    # after unencrypt cip result this return like string so we need parse this
    # for access cip data in more easy way
    def parse_cip_result uncrypt_text, keys=[]
      parser = Nori.new
      cip = parser.parse uncrypt_text
      if keys.length > 0
        result = cip

        keys.map do |k|
          result = result[k]
        end
        result
      else
        cip
      end
    end

    # Build an xml with given options
    # cod_serv: service code, provided by pago efectivo
    # currency: currency of operation, once of PagoEfectivo::CURRENCIES
    # total: total operation. 18 enteros, 2 decimales.
    # pay_method: desired pay method, once of PagoEfectivo::PAY_METHODS
    # cod_transaction: transaction reference
    # email: commerce email
    # user: an object or hash that represent a customer
    # - first_name: customer first name
    # - last_name: customer last name
    # - doc_type: document type. DNI, LE, RUC
    # - doc_num: document number
    # - id: commerce customer identifier
    # - email: customer email
    # additional_data: additional information
    # exp_date: cip expiration date. Should be in the format '31/10/2014 17:00:00',
    # place: an object or hash that represent a customer address
    # - loc: customer address location. Ex: Surco
    # - prov: customer address province. Ex: Lima
    # - country: customer address country: Ex: Peru
    # pay_concept: an order reference
    # origin_code
    # origin_type
    def generate_xml(opts = {})
      child_hash = {
        sol_pago: {
          id_moneda: opts[:currency][:id],
          total: opts[:total],
          metodos_pago: opts[:pay_method],
          cod_servicio: opts[:cod_serv],
          codtransaccion: opts[:cod_transaction],
          email_comercio: opts[:email],
          fecha_a_expirar: opts[:exp_date],
          usuario_id: opts[:user][:id],
          data_adicional: opts[:additional_data],
          usuario_nombre: opts[:user][:first_name],
          usuario_apellidos: opts[:user][:last_name],
          usuario_localidad: opts[:place][:loc],
          usuario_provincia: opts[:place][:prov],
          usuario_pais: opts[:place][:country],
          usuario_alias: '',
          usuario_tipo_doc: opts[:user][:doc_type],
          usuario_numero_doc: opts[:user][:doc_num],
          usuario_email: opts[:user][:email],
          concepto_pago: opts[:pay_concept],
          detalles: {
            detalle: {
              cod_origen: opts[:origin_code],
              tipo_origen: opts[:origin_type],
              concepto_pago: opts[:pay_concept],
              importe: opts[:total],
              campo1: '',
              campo2: '',
              campo3: '',
            }
          },
          params_url: {
            param_url: {
              nombre: 'IDCliente',
              valor: opts[:user][:id]
            },
            params_email: {
              param_email: {
                nombre: '[UsuarioNombre]',
                valor: opts[:user][:first_name]
              },
              param_email: {
                nombre: '[Moneda]',
                valor: opts[:currency][:symbol]
              }
            }
          }
        }
      }
      child_options = { key_converter: :camelcase}
      gyoku_xml = Gyoku.xml(child_hash, child_options)
      xml_child = create_markup(gyoku_xml)
    end

    # cod_serv: service code, provided by pago efectivo
    # signer: xml signed with private key
    # xml: encrypted xml
    def generate_cip(cod_serv, signer, xml)
      response = @cip_client.call(:generar_cip_mod1, message: {
                              request: {
                                'CodServ' => cod_serv,
                                'Firma' => signer,
                                'Xml' => xml
                            }})
      response.to_hash[:generar_cip_mod1_response][:generar_cip_mod1_result]
    end

    # cod_serv: service code, provided by pago efectivo
    # cips: string of cips separated with comma (,)
    # signed_cips: cips passed by signer method
    # encrypted_cips: cips passed by encrypted method
    # info_request: no specified in pago efectivo documentation, send blank
    #               for now
    def consult_cip cod_serv, signed_cips, encrypted_cips, info_request=''
      response = @cip_client.call(:consultar_cip_mod1, message: {
                   'request' => {
                     'CodServ' => cod_serv,
                     'Firma' => signed_cips,
                     'CIPS' => encrypted_cips,
                     info_request: info_request
                   }
                 })
      response.to_hash[:consultar_cip_mod1_response][:consultar_cip_mod1_result]
    end

    # after unencrypt consult cip result this return string so we need parse
    # this for access cip data in more easy way
    def parse_consult_cip_result uncrypt_text
      parser = Nori.new
      cip = parser.parse uncrypt_text
      # TODO: parse response for multiple cips
      cip['ConfirSolPagos']['ConfirSolPago']['CIP']
    end

    # cod_serv: service code, provided by pago efectivo
    # signed_cip: number of cip to delete passed by signer method
    # encrypted_cip: number of cip to delete passed by encrypted method
    # info_request: no specified in pago efectivo documentation, send blank
    #               for now
    def delete_cip cod_serv, signed_cip, encrypted_cip, info_request=''
      response = @cip_client.call(:eliminar_cip_mod1, message: {
                   'request' => {
                     'CodServ' => cod_serv,
                     'Firma' => signed_cip,
                     'CIP' => encrypted_cip,
                     'InfoRequest' => info_request
                   }
                 })
      response.to_hash[:eliminar_cip_mod1_response][:eliminar_cip_mod1_result]
    end

    # cod_serv: service code, provided by pago efectivo
    # signed_cip: number of cip to modify passed by signer method
    # encrypted_cip: number of cip to modify passed by encrypted method
    # exp_date: new expiration date, should be DateTime class
    # info_request: no specified in pago efectivo documentation, send blank
    #               for now
    def update_cip cod_serv,signed_cip,encrypted_cip,exp_date,info_request=''
      response = @cip_client.call(:actualizar_cip_mod1, message: {
                   'request' => {
                     'CodServ' => cod_serv,
                     'Firma' => signed_cip,
                     'CIP' => encrypted_cip,
                     'FechaExpira' => exp_date,
                     'InfoRequest' => info_request
                   }
                 })
      response.to_hash[:actualizar_cip_mod1_response][:actualizar_cip_mod1_result]
    end
  end
end
