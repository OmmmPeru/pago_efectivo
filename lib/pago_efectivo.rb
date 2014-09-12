require 'savon'
require 'gyoku'
require 'nokogiri'

module PagoEfectivo
  CURRENCIES = {soles: {id: 1, symbol: 'S/.'}, dolares: {id: 2, symbol: '$'}}
  PAY_METHODS = [1,2] #[{'bancos' => 1}, {'cuenta_virtual' => 2}]

  class Client
    SCHEMA_TYPES = {
      'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
      'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
      'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/'
    }

    def initialize env=nil
      if env == 'production'
        @api_server = 'https://pagoefectivo.pe'
      else
        @api_server = 'http://pre.pagoefectivo.pe'
      end

      if ENV['QUOTAGUARDSTATIC_URL'] != nil
        @proxy = ENV['QUOTAGUARDSTATIC_URL']
      end
      @crypto_path = '/PagoEfectivoWSCrypto/WSCrypto.asmx?WSDL'
      @cip_path = '/PagoEfectivoWSGeneralv2/service.asmx?WSDL'
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
      server = @api_server + @crypto_path
      client = Savon.client(wsdl: server, proxy: @proxy)
      response = client.call(:signer, message: {
                              plain_text: text, private_key: @private_key
                            })
      response.to_hash[:signer_response][:signer_result]
    end

    def encrypt_text(text)
      server = @api_server + @crypto_path
      client = Savon.client(wsdl: server, proxy: @proxy)
      response = client.call(:encrypt_text, message: {
                              plain_text: text, public_key: @public_key
                            })
      response.to_hash[:encrypt_text_response][:encrypt_text_result]
    end

    def unencrypt enc_text
      server = @api_server + @crypto_path
      client = Savon.client(wsdl: server, proxy: @proxy)
      response = client.call(:decrypt_text, message: {
                              encrypt_text: enc_text, private_key: @private_key
                            })
      response.to_hash[:decrypt_text_response][:decrypt_text_result]
    end

    def generate_xml(cod_serv, currency, total, pay_methods, cod_trans, email,
                     user, additional_data, exp_date, place, pay_concept,
                     origin_code, origin_type)
      # cod_serv => código de servicio asignado
      # signer => trama firmada con llave privada
      child_hash = { sol_pago: {
                 id_moneda: currency[:id],
                 total: total, # 18 enteros, 2 decimales. Separados por `,`
                 metodos_pago: pay_methods,
                 cod_servicio: cod_serv,
                 codtransaccion: cod_trans, # referencia al pago
                 email_comercio: email,
                 fecha_a_expirar: exp_date, # (DateTime.now + 4).to_s(:db)
                 usuario_id: user[:id],
                 data_adicional: additional_data,
                 usuario_nombre: user[:first_name],
                 usuario_apellidos: user[:last_name],
                 usuario_localidad: place[:loc],
                 usuario_provincia: place[:prov],
                 usuario_pais: place[:country],
                 usuario_alias: '',
                 usuario_tipo_doc: user[:doc_type], # tipo de documento DNI, LE, RUC
                 usuario_numero_doc: user[:doc_num],
                 usuario_email: user[:email],
                 concepto_pago: pay_concept,
                 detalles: {
                   detalle: {
                     cod_origen: origin_code,
                     tipo_origen: origin_type,
                     concepto_pago: pay_concept,
                     importe: total,
                     campo1: '',
                     campo2: '',
                     campo3: '',
                   }
                 },
                 params_url: {
                   param_url: {
                     nombre: 'IDCliente',
                     valor: user[:id]
                   },
                   params_email: {
                     param_email: {
                       nombre: '[UsuarioNombre]',
                       valor: user[:first_name]
                     },
                     param_email: {
                       nombre: '[Moneda]',
                       valor: currency[:symbol]
                     }
                   }
                 }
               }
             }
      child_options = { key_converter: :camelcase}
      gyoku_xml = Gyoku.xml(child_hash, child_options)
      xml_child = create_markup(gyoku_xml)
    end

    def generate_cip(cod_serv, signer, xml)
      server = @api_server + @cip_path
      client = Savon.client(wsdl: server, proxy: @proxy)
      response = client.call(:generar_cip_mod1, message: {
                              request: {
                                'CodServ' => cod_serv,
                                'Firma' => signer,
                                'Xml' => xml
                            }})
      response.to_hash[:generar_cip_mod1_response][:generar_cip_mod1_result]
    end

    def consult_cip capi, key, cips, info_request=nil
      path = '/PagoEfectivoWSGeneral/WSCIP.asmx'
      cip_arr = {}
      cips.each do |cip|
        cip_arr = cip_arr.merge({string: cip})
      end
      hash = { consultar_cip: {request: {
                 CAPI: capi, c_clave: key,
                 CIPS: cip_arr,
                info_request: info_request
              }}}
      options = { key_converter: :camelcase}
      attributes = {"soap:Envelope" => SCHEMA_TYPES}
      xml_body = Gyoku.xml({"soap:Envelope" => {"soap:Body" => hash},
                            :attributes! => attributes}, options)

      xml = create_markup(xml_body)

      server = @api_server + path
      response = Ox.parse(@request.new(server, verify_ssl: true).post(xml))
      response.decrypt_text_response
    end

    def delete_cip
    end

    def update_cip
    end
  end
end
