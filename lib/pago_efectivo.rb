require 'gyoku'
require 'builder'
require 'rest-client'
require 'ox'

module PagoEfectivo

  SCHEMA_TYPES = {
    'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
    'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
    'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/'
  }

  def initialize
    @api_server = 'https://pre.pagoefectivo.pe'
    @request = RestClient::Resource
  end

  def create_markup(body)
    xml_markup = Builder::XmlMarkup.new(indent: 2)
    xml_markup.instruct! :xml
    xml_markup << body.to_s
    xml_markup
  end

  def signature(text, private_key)
    path = '/PagoEfectivoWSCrypto/WSCrypto.asmx'
    hash = { signer: { plain_text: text, private_key: private_key }}
    options = { key_converter: :camelcase, key_to_convert: 'signer'}
    attributes = {"soap:Envelope" => SCHEMA_TYPES}
    xml_body = Gyoku.xml({"soap:Envelope" => {"soap:Body" => hash},
                          :attributes! => attributes}, options)

    xml = create_markup(xml_body)

    server = @api_server + path
    response = Ox.parse(@request.new(server, verify_ssl: true).post(xml))
    response.signer_result
  end

  def encrypt_text(text, public_key)
    path = '/PagoEfectivoWSCrypto/WSCrypto.asmx'
    hash = { encrypt_text: { plain_text: text, public_key: public_key }}
    options = { key_converter: :camelcase, key_to_convert: 'encrypt_text'}
    attributes = {"soap:Envelope" => SCHEMA_TYPES}
    xml_body = Gyoku.xml({"soap:Envelope" => {"soap:Body" => hash},
                          :attributes! => attributes}, options)

    xml = create_markup(xml_body)
    server = @api_server + path
    response = Ox.parse(@request.new(server, verify_ssl: true).post(xml))
    response.encrypt_text_result
  end

  def generate_cip(signer, currency, total, pay_methods, cod_trans, email,
                   user, additional_data)
    # Cóidgo de servicio asignado
    cServ = 'MEEH'
    cClave = signer
    hash = { sol_pago: {
               id_moneda: currency.id,
               total: total,
               metodos_pago: pay_methods,
               cod_servicio: cServ,
               cod_transaccion: cod_trans,
               email_comercio: email,
               fecha_a_expirar: (DateTime.now + 4).to_s(:db),
               usuario_id: user.id,
               data_adicional: additional_data,
               usuario_nombre: user.first_name,
               usuario_apellidos: user.last_name,
               usuario_localidad: ,
               usuario_provincia: ,
               usuario_pais: ,
               usuario_alias: ,
               usuario_tipo_doc: ,
               usuario_numero_doc: ,
               usuario_email: ,
               concepto_pago: ,
               detalles: {
                 detalle: {
                   cod_origen: ,
                   tipo_origen: ,
                   concepto_pago: ,
                   importe: total,
                   campo1: '',
                   campo2: '',
                   campo3: '',
                 }
               },
               params_url: {
                 param_url: {
                   nombre: 'IDCliente',
                   valor:
                 },
                 param_url: {
                   nombre: 'FechaHoraRegistro',
                   valor: DateTime.now.to_s(:db)
                 },
                 params_email: {
                   param_email: {
                     nombre: '[UsuarioNombre]'
                     valor: user.first_name
                   },
                   param_email: {
                     nombre: '[Moneda]',
                     valor: currency.symbol
                   }
                 }
               }
             }
           }
  end

  def consult_cip
  end

  def delete_cip
  end

  def update_cip
  end
end
