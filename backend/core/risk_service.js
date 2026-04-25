/**
 * risk_service.js
 *
 * Bridge to Alibaba Cloud PAI (Platform for AI) EAS (Elastic Algorithm Service).
 * This service calculates the "Safe Offline Limit" RMRM.
 */

import axios from 'axios';

class RiskService {
  constructor(endpoint, token) {
    this.endpoint = endpoint;
    this.token = token;
  }

  /**
   * Call Alibaba Cloud PAI EAS endpoint to get a risk-adjusted offline limit.
   *
   * @param {string} userId
   * @param {object} features { kyc_level, tx_frequency, avg_tx_value, etc }
   * @returns {Promise<number>} offline_limit_myr
   */
  async getOfflineLimit(userId, features) {
    try {
      // Real implementation would use Alibaba Cloud SDK or signed HTTP request
      const response = await axios.post(
        this.endpoint,
        {
          user_id: userId,
          features: features,
        },
        {
          headers: {
            'Authorization': this.token,
            'Content-Type': 'application/json',
          },
          timeout: 2000, // Strict timeout for AI inference
        }
      );

      return response.data.safe_limit_myr ?? 50.00; // Default RM 50 if model fails
    } catch (error) {
      console.error('Alibaba PAI Inference Failed:', error.message);
      return 30.00; // Safe fallback limit
    }
  }
}

let _instance = null;

export function getRiskService() {
  if (!_instance) {
    _instance = new RiskService(
      process.env.ALIBABA_PAI_ENDPOINT || 'https://pai-eas.ap-southeast-1.aliyuncs.com/predict/risk_v1',
      process.env.ALIBABA_PAI_TOKEN || 'MOCK_TOKEN'
    );
  }
  return _instance;
}
