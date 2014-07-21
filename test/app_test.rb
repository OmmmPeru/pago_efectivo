require_relative 'helper'
include PagoEfectivo

scope do
  test 'test' do
    req = PagoEfectivo.request_signature('text', 'key')
    assert req.include?('?xml')
    assert req.include?('xmlns:soap')
  end
end
