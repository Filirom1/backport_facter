module Facter::Core::Resolvable
  def value
    result = nil

    if limit != 0 
      Facter.warn("Fact timeout is deprecated, use execution timeout instead #FACT-886: Expose a timeout option on the Ruby Facter API")
    end

    with_timing do
      result = resolve_value
    end

    Facter::Util::Normalization.normalize(result)
  rescue Facter::Util::Normalization::NormalizationError => detail
    Facter.log_exception(detail, "Fact resolution #{qualified_name} resolved to an invalid value: #{detail.message}")
    return nil
  rescue => detail
    Facter.log_exception(detail, "Could not retrieve #{qualified_name}: #{detail.message}")
    return nil
  end
end
